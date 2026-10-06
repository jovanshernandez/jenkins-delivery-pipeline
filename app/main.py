"""delivery-app: the small HTTP service this pipeline tests, packages and deploys.

Endpoints
  GET /         service banner
  GET /health   liveness: the process is up
  GET /ready    readiness: the app finished loading and has build identity
  GET /version  build identity injected by the pipeline (GIT_SHA, BUILD_NUMBER)
  GET /metrics  Prometheus exposition format
"""

import os
import time

from flask import Flask, Response, g, jsonify, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    disable_created_metrics,
    generate_latest,
)

# Drop the *_created companion series; they add noise without adding signal here.
disable_created_metrics()

SERVICE_NAME = "delivery-app"


def build_info(env=None):
    """Read build identity from the environment the image was started with."""
    env = os.environ if env is None else env
    return {
        "service": SERVICE_NAME,
        "version": env.get("APP_VERSION", "dev"),
        "git_sha": env.get("GIT_SHA", "unknown"),
        "build_number": env.get("BUILD_NUMBER", "local"),
    }


def create_app(env=None):
    app = Flask(__name__)
    info = build_info(env)
    started = time.time()

    registry = CollectorRegistry()
    requests_total = Counter(
        "http_requests_total",
        "HTTP requests served.",
        ["method", "endpoint", "status"],
        registry=registry,
    )
    latency = Histogram(
        "http_request_duration_seconds",
        "HTTP request latency.",
        ["endpoint"],
        registry=registry,
    )
    Gauge(
        "app_build_info",
        "Build identity of the running service (always 1).",
        ["version", "git_sha"],
        registry=registry,
    ).labels(info["version"], info["git_sha"]).set(1)
    Gauge(
        "app_uptime_seconds", "Seconds since the app started.", registry=registry
    ).set_function(lambda: time.time() - started)

    @app.before_request
    def _start_timer():
        g.started = time.perf_counter()

    @app.after_request
    def _record(response):
        endpoint = request.url_rule.rule if request.url_rule else "unmatched"
        if endpoint != "/metrics":
            requests_total.labels(request.method, endpoint, response.status_code).inc()
            latency.labels(endpoint).observe(time.perf_counter() - g.started)
        return response

    @app.get("/")
    def index():
        return jsonify(service=SERVICE_NAME, message="ok", version=info["version"])

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/ready")
    def ready():
        checks = {"app_loaded": True, "build_identity": info["git_sha"] != "unknown"}
        return jsonify(status="ready", checks=checks)

    @app.get("/version")
    def version():
        return jsonify(info)

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)

    return app


app = create_app()
