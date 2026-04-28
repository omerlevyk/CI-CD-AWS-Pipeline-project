FROM python:3.11 AS builder
WORKDIR /install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11
WORKDIR /app
COPY . .
COPY --from=builder /usr/local /usr/local

ENV PATH="/root/.local/bin:$PATH"
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

CMD ["python", "weather_app.py"]

