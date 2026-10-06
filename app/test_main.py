import pytest

from main import build_info, create_app

BUILD_ENV = {"APP_VERSION": "1.4.0", "GIT_SHA": "3f9c2ab", "BUILD_NUMBER": "42"}


@pytest.fixture
def client():
    return create_app(BUILD_ENV).test_client()


def test_root_returns_service_banner(client):
    resp = client.get("/")

    assert resp.status_code == 200
    assert resp.json == {"service": "delivery-app", "message": "ok", "version": "1.4.0"}


def test_health_is_ok(client):
    resp = client.get("/health")

    assert resp.status_code == 200
    assert resp.json == {"status": "ok"}


def test_ready_reports_build_identity(client):
    resp = client.get("/ready")

    assert resp.status_code == 200
    assert resp.json["status"] == "ready"
    assert resp.json["checks"] == {"app_loaded": True, "build_identity": True}


def test_version_comes_from_pipeline_env(client):
    resp = client.get("/version")

    assert resp.status_code == 200
    assert resp.json == {
        "service": "delivery-app",
        "version": "1.4.0",
        "git_sha": "3f9c2ab",
        "build_number": "42",
    }


def test_version_defaults_outside_the_pipeline():
    assert build_info({}) == {
        "service": "delivery-app",
        "version": "dev",
        "git_sha": "unknown",
        "build_number": "local",
    }


def test_ready_without_build_identity_still_serves():
    resp = create_app({}).test_client().get("/ready")

    assert resp.status_code == 200
    assert resp.json["checks"]["build_identity"] is False


def test_metrics_exposes_prometheus_format(client):
    client.get("/health")
    client.get("/health")
    client.get("/does-not-exist")

    resp = client.get("/metrics")
    body = resp.get_data(as_text=True)

    assert resp.status_code == 200
    assert resp.content_type.startswith("text/plain")
    assert 'http_requests_total{endpoint="/health",method="GET",status="200"} 2.0' in body
    assert 'http_requests_total{endpoint="unmatched",method="GET",status="404"} 1.0' in body
    assert 'app_build_info{git_sha="3f9c2ab",version="1.4.0"} 1.0' in body
    assert "http_request_duration_seconds_bucket" in body
    assert "app_uptime_seconds" in body


def test_metrics_scrapes_are_not_counted(client):
    client.get("/metrics")
    body = client.get("/metrics").get_data(as_text=True)

    assert 'endpoint="/metrics"' not in body
