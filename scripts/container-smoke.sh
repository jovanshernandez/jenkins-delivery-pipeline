#!/usr/bin/env bash
# Start an image on a random local port, run the smoke test against it, and
# always remove the container. Used by the Jenkins "Image smoke test" stage and CI.
#
#   scripts/container-smoke.sh IMAGE [EXPECTED_GIT_SHA]
set -euo pipefail

image="${1:?usage: container-smoke.sh IMAGE [EXPECTED_GIT_SHA]}"
expected_sha="${2:-}"
here="$(cd "$(dirname "$0")" && pwd)"

cid="$(docker run --detach --read-only --tmpfs /tmp --publish 127.0.0.1::8000 "${image}")"
cleanup() {
  local status=$?
  if ((status != 0)); then
    docker logs "${cid}" >&2 || true
  fi
  docker rm --force "${cid}" >/dev/null
}
trap cleanup EXIT

port="$(docker port "${cid}" 8000/tcp | head -n1 | awk -F: '{print $NF}')"
echo "smoke testing ${image} on port ${port}"
"${here}/smoke-test.sh" "http://127.0.0.1:${port}" "${expected_sha}"
