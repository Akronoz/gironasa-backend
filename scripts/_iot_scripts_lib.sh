#!/usr/bin/env bash
# Helpers compartidos para scripts IoT (sma-server en wg-easy → 10.8.0.1:8000).

_iot_load_env() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  if [[ -f "$root/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$root/.env"
    set +a
  fi
}

resolve_sma_base_url() {
  if [[ -n "${SMA_BASE_URL:-}" ]]; then
    echo "$SMA_BASE_URL"
    return 0
  fi
  if curl -sf --connect-timeout 2 http://10.8.0.1:8000/health >/dev/null 2>&1; then
    echo "http://10.8.0.1:8000"
    return 0
  fi
  if curl -sf --connect-timeout 2 http://127.0.0.1:8000/health >/dev/null 2>&1; then
    echo "http://127.0.0.1:8000"
    return 0
  fi
  return 1
}

purge_device_influx_direct() {
  local device_id="$1"
  local org="${INFLUX_ORG:-Gironasa}"
  local bucket="${INFLUX_BUCKET:-sma}"
  local url="${INFLUX_URL:-http://127.0.0.1:8086}"
  local token="${INFLUX_TOKEN:-}"
  local stop
  stop="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ -z "$token" ]]; then
    echo "ERROR: falta INFLUX_TOKEN en .env" >&2
    return 1
  fi

  curl -sS -X POST \
    "${url}/api/v2/delete?org=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$org'))")&bucket=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$bucket'))")" \
    -H "Authorization: Token ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"start\":\"1970-01-01T00:00:00Z\",\"stop\":\"${stop}\",\"predicate\":\"_measurement=\\\"iot_telemetry\\\" AND device_id=\\\"${device_id}\\\"\"}"
}