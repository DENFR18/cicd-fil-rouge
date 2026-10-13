FROM python:3.12-slim

# Version et injection de pannes, figées au build (voir .github/workflows/publish-images.yml)
ARG APP_VERSION=dev
ARG FAILURE_RATE=0
ARG LATENCY_MS=0
ENV APP_VERSION=${APP_VERSION} \
    FAILURE_RATE=${FAILURE_RATE} \
    LATENCY_MS=${LATENCY_MS} \
    DB_PATH=/tmp/taskflow.db \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN useradd --uid 10001 --no-create-home appuser
USER 10001

