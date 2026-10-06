# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /srv/app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY main.py .

# Build identity is baked in by the pipeline and surfaced at /version and /metrics.
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
ARG BUILD_NUMBER=local
ENV APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA} \
    BUILD_NUMBER=${BUILD_NUMBER}

LABEL org.opencontainers.image.title="delivery-app" \
      org.opencontainers.image.source="https://github.com/jovanshernandez/jenkins-delivery-pipeline" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.version="${APP_VERSION}"

RUN useradd --system --uid 10001 --no-create-home app
USER 10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"

# One worker keeps the in-process Prometheus metrics consistent; threads handle concurrency.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", \
     "--worker-tmp-dir", "/dev/shm", "--access-logfile", "-", "main:app"]
