#!/usr/bin/env bash
# Post-deploy smoke test for delivery-app.
#
#   scripts/smoke-test.sh [BASE_URL] [EXPECTED_GIT_SHA]
#
# Checks liveness, readiness and metrics, and when EXPECTED_GIT_SHA is given,
# fails unless /version reports that exact build. Retries while the app starts.
set -euo pipefail

base_url="${1:-http://localhost:8000}"
expected_sha="${2:-}"
attempts="${SMOKE_ATTEMPTS:-15}"

for ((i = 1; i <= attempts; i++)); do
  if curl --fail --silent --max-time 3 "${base_url}/health" >/dev/null; then
    break
  fi
  if ((i == attempts)); then
    echo "FAIL /health did not respond after ${attempts} attempts" >&2
    exit 1
  fi
  sleep 2
done
echo "ok   /health"

curl --fail --silent --max-time 3 "${base_url}/ready" | grep --quiet '"status":"ready"'
echo "ok   /ready"

version="$(curl --fail --silent --max-time 3 "${base_url}/version")"
if [[ -n "${expected_sha}" ]] && ! grep --quiet "\"git_sha\":\"${expected_sha}\"" <<<"${version}"; then
  echo "FAIL /version reports ${version}, expected git_sha ${expected_sha}" >&2
  exit 1
fi
echo "ok   /version ${version}"

curl --fail --silent --max-time 3 "${base_url}/metrics" | grep --quiet '^app_build_info'
echo "ok   /metrics"
