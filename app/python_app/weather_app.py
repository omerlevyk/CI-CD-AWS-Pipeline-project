import uuid
import json
import os
import re
import requests
from datetime import datetime
from pathlib import Path
from flask import Flask, render_template, request, jsonify, send_file, abort
from prometheus_client import Counter, generate_latest
from flask import Response

try:
    import boto3
except ImportError:
    boto3 = None

app = Flask(__name__)
BASE_DIR = Path(__file__).resolve().parent
HISTORY_DIR = Path(os.getenv("HISTORY_DIR", BASE_DIR / "history"))

city_search_counter = Counter(
    "city_search_total",
    "Number of times each city was searched",
    ["city"]
)

class APIError(Exception): pass # api request failed
class DataParsingError(Exception): pass # api missing data or at unexpected format

table = None
if boto3 is not None:
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table = dynamodb.Table("WeatherHistory")

def user_input(form):
    """extract and clean user input from Flask form"""
    city = form.get("city")
    if not city or not city.strip():
        raise ValueError("[VALUE ERROR] city name cannot be empty")
    return city.strip()

def validate_user_input(city_name):
    """Used for pytest, validates simple city string input"""
    if not city_name or not isinstance(city_name, str):
        raise ValueError("[VALUE ERROR] invalid city name")
    return city_name.strip()

def get_api(city_name):
    loc = fetch_geocode(city_name)
    raw_data = fetch_weather_api(loc["lat"], loc["lon"])
    return loc, raw_data

def fetch_geocode(city_name):
    """Call geocoding API and return coordinates && metadata"""
    geo_url = "https://geocoding-api.open-meteo.com/v1/search"
    params = {"name": city_name, "count": 1}

    try:
        data = api_fetch(geo_url, params)
    except Exception as e:
        raise APIError(f"[API ERROR] Geocoding request failed: {e}")

    if not data.get("results"):
        raise DataParsingError("city not found in geocoding API")

    result = data["results"][0]

    required_fields = ["latitude", "longitude", "name"]
    if not all(field in result for field in required_fields):
        raise DataParsingError("Incomplete geocoding data received")

    return {
        "lat": result["latitude"],
        "lon": result["longitude"],
        "city": result["name"],
        "country": result.get("country", "")
    }

def fetch_weather_api(lat, lon):
    """call weather API and return raw JSON file"""
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "daily": "temperature_2m_max,temperature_2m_min",
        "hourly": "relativehumidity_2m",
        "timezone": "auto"
    }

    try:
        data = api_fetch(url, params)
    except Exception as e:
        raise APIError(f"Weather API request failed: {e}")

    # validate structure
    if "daily" not in data or "temperature_2m_max" not in data["daily"]:
        raise DataParsingError("Daily weather data missing in API response")

    if "hourly" not in data or "relativehumidity_2m" not in data["hourly"]:
        raise DataParsingError("Hourly humidity data missing in API response")

    return data

def api_fetch(url, params):
        try:
            resp = requests.get(url, params=params, timeout=5)
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            raise APIError(f"API request faild: {e}")

def filter_data(api_data):
    """convert raw API data into list of structured daily entries"""
    if "daily" not in api_data:
        raise DataParsingError("Missing daily section in API response")

    daily = api_data["daily"]
    humidity_map = extract_humidity_map(api_data)

    try:
        return [
            build_day_entry(date_str, daily, humidity_map)
            for date_str in daily["time"]
        ]
    except Exception as e:
        raise DataParsingError(f"Failed building daily weather entries: {e}")

def extract_humidity_map(api_data):
    try:
        hourly_times = api_data["hourly"]["time"]
        hourly_humidity = api_data["hourly"]["relativehumidity_2m"]
    except KeyError:
        raise DataParsingError("Hourly data missing in API response")

    humidity_map = {}

    for t, hum in zip(hourly_times, hourly_humidity):
        # Flexible match (08:00, 08:15 etc)
        if t.startswith(t.split("T")[0] + "T08"):
            day = t.split("T")[0]
            humidity_map[day] = hum

    if not humidity_map:
        raise DataParsingError("No humidity readings found at around 08:00")

    return humidity_map

def build_day_entry(date_str, daily, humidity_map):
    """build entry for a single day's weather"""
    if date_str not in daily["time"]:
        raise DataParsingError(f"Missing daily record for date {date_str}")

    idx = daily["time"].index(date_str)

    date_obj = datetime.strptime(date_str, "%Y-%m-%d")

    return {
        "day_name": date_obj.strftime("%A"),
        "pretty_date": date_obj.strftime("%d/%m"),
        "day_temp": daily["temperature_2m_max"][idx],
        "night_temp": daily["temperature_2m_min"][idx],
        "humidity": humidity_map.get(date_str, "N/A")
    }


def _sanitize_city_name(city_name):
    clean_name = re.sub(r"[^a-zA-Z0-9_-]+", "_", city_name.strip().lower())
    return clean_name.strip("_") or "unknown_city"


def save_search_history(city_name, location, weather):
    HISTORY_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.utcnow()
    day_dir = HISTORY_DIR / now.strftime("%Y-%m-%d")
    day_dir.mkdir(parents=True, exist_ok=True)

    file_name = f"{_sanitize_city_name(city_name)}_{now.strftime('%H%M%S_%f')}.json"
    file_path = day_dir / file_name
    payload = {
        "searched_city": city_name,
        "timestamp_utc": now.isoformat(timespec="seconds") + "Z",
        "location": location,
        "weather": weather,
    }

    with file_path.open("w", encoding="utf-8") as history_file:
        json.dump(payload, history_file, indent=2)

    return file_path


def list_history_files():
    if not HISTORY_DIR.exists():
        return []

    files = sorted(HISTORY_DIR.rglob("*.json"), key=lambda path: path.stat().st_mtime, reverse=True)
    history_items = []

    for file_path in files:
        rel_path = file_path.relative_to(HISTORY_DIR)
        item = {
            "file_name": rel_path.name,
            "download_key": rel_path.as_posix(),
            "day": rel_path.parts[0] if len(rel_path.parts) > 1 else "unknown-day",
            "city": rel_path.stem.split("_")[0],
        }

        try:
            with file_path.open("r", encoding="utf-8") as history_file:
                payload = json.load(history_file)
                item["city"] = payload.get("location", {}).get("city") or payload.get("searched_city") or item["city"]
                item["timestamp_utc"] = payload.get("timestamp_utc", "")
        except (json.JSONDecodeError, OSError):
            item["timestamp_utc"] = ""

        history_items.append(item)

    return history_items


def get_bg_color():
    return os.getenv("BG_COLOR", "#f8f9fa")

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain")

@app.route("/api/sky", methods=["GET"])
def get_sky_img():
    return jsonify({"url": "https://weather-site-omerlevy03.s3.us-east-1.amazonaws.com/sky.jpg"})

@app.route("/api/save", methods=["POST"])
def save_weather():
    if table is None:
        return jsonify({"error": "DynamoDB client is not available"}), 503

    data = request.json
    item = {
        "id": str(uuid.uuid4()),
        "city": data["city"],
        "country": data["country"],
        "weather": data["weather"]
    }
    table.put_item(Item=item)
    return jsonify({"status": "saved"})

@app.route("/", methods=["GET", "POST"])
def index():
    error = None
    location = None
    weather = None

    if request.method == "POST":
        try:
            city = validate_user_input(user_input(request.form))
            city_search_counter.labels(city=city).inc()
            location, api_data = get_api(city)
            weather = filter_data(api_data)
            save_search_history(city, location, weather)

        except ValueError as e:
            error = f"[INPUT ERROR] {e}"

        except APIError as e:
            error = f"[API ERROR] {e}"

        except DataParsingError as e:
            error = f"[DATA ERROR] {e}"

        except Exception as e:
            error = f"[UNKNOWN ERROR] {e}"

    return render_template("index.html", location=location, weather=weather, error=error, bg_color=get_bg_color())


@app.route("/history", methods=["GET"])
def history():
    return render_template("history.html", history_items=list_history_files(), bg_color=get_bg_color())


@app.route("/history/download/<path:download_key>", methods=["GET"])
def history_download(download_key):
    requested_path = (HISTORY_DIR / download_key).resolve()

    try:
        requested_path.relative_to(HISTORY_DIR.resolve())
    except ValueError:
        abort(400, description="Invalid history file path")

    if not requested_path.exists() or requested_path.suffix != ".json":
        abort(404, description="History file not found")

    return send_file(requested_path, as_attachment=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
