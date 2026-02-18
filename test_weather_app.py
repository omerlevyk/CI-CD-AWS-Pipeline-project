#Approved by: Sergei

import pytest
from unittest.mock import patch, MagicMock
from types import SimpleNamespace
from weather_app import APIError, DataParsingError
from weather_app import user_input, validate_user_input
from weather_app import get_api, fetch_geocode, fetch_weather_api, api_fetch
from weather_app import filter_data, extract_humidity_map, build_day_entry
from weather_app import save_search_history, list_history_files, get_bg_color

""" input testing """

def test_input_is_invalid():
    assert validate_user_input(" Haifa ") == "Haifa"

def test_input_is_empty():
    with pytest.raises(ValueError):
        validate_user_input("")

def test_user_input_with_spaces():
    form = SimpleNamespace(get=lambda k: " Tel Aviv ")
    assert user_input(form) == "Tel Aviv"

""" API fatch testing """

@patch("weather_app.requests.get")
def test_api_fatch_success(mock_get):
    mock_response = MagicMock()
    mock_response.json.return_value = {"ok": True}
    mock_response.raise_for_status.return_value = None
    mock_get.return_value = mock_response

    assert api_fetch("x", {}) == {"ok": True}

@patch("weather_app.requests.get")
def test_api_fatch_error(mock_get):
    mock_response = MagicMock()
    mock_response.raise_for_status.side_effect = Exception("err")
    mock_get.return_value = mock_response
    with pytest.raises(APIError):
        api_fetch("x", {})

""" data filtering testing """

def test_extract_humidity_map():
    api_data = {
        "hourly": {
            "time": ["2025-12-09T08:00"],
            "relativehumidity_2m": [60]
        }
    }
    assert extract_humidity_map(api_data) == {"2025-12-09": 60}

def test_build_day_entry():
    daily = {
        "time": ["2025-12-09"],
        "temperature_2m_max": [20],
        "temperature_2m_min": [12],
    }
    hum = {"2025-12-09": 60}
    entry = build_day_entry("2025-12-09", daily, hum)
    assert entry["day_temp"] == 20
    assert entry["night_temp"] == 12
    assert entry["humidity"] == 60

def test_filter_data():
    api_data = {
        "daily": {
            "time": ["2025-12-09"],
            "temperature_2m_max": [20],
            "temperature_2m_min": [12],
        },
        "hourly": {
            "time": ["2025-12-09T08:00"],
            "relativehumidity_2m": [60],
        },
    }
    result = filter_data(api_data)
    assert len(result) == 1
    assert result[0]["humidity"] == 60


def test_save_search_history(tmp_path, monkeypatch):
    monkeypatch.setattr("weather_app.HISTORY_DIR", tmp_path)
    location = {"city": "Tel Aviv", "country": "Israel"}
    weather = [{"day_name": "Monday"}]

    file_path = save_search_history("Tel Aviv", location, weather)

    assert file_path.exists()
    assert file_path.suffix == ".json"
    assert file_path.parent.parent == tmp_path


def test_list_history_files(tmp_path, monkeypatch):
    monkeypatch.setattr("weather_app.HISTORY_DIR", tmp_path)
    save_search_history("Haifa", {"city": "Haifa", "country": "Israel"}, [{"day_name": "Tuesday"}])
    items = list_history_files()

    assert len(items) == 1
    assert items[0]["city"] == "Haifa"
    assert items[0]["file_name"].endswith(".json")


def test_bg_color_from_env(monkeypatch):
    monkeypatch.setenv("BG_COLOR", "#00ff00")
    assert get_bg_color() == "#00ff00"
