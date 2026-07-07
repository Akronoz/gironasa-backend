#!/usr/bin/env bash
# Lista device_id con telemetría en Influx (últimas 30 días) y el registro en sma-server.
# Uso: cd ~/gironasa/sma-server && bash scripts/list_iot_devices.sh

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

ORG="${INFLUX_ORG:-Gironasa}"
BUCKET="${INFLUX_BUCKET:-sma}"
URL="${INFLUX_URL:-http://127.0.0.1:8086}"
TOKEN="${INFLUX_TOKEN:-}"
API_KEY="${SMA_API_KEY:-}"
BASE_URL="${SMA_BASE_URL:-http://127.0.0.1:8000}"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: falta INFLUX_TOKEN en .env"
  exit 1
fi

echo "=== device_id en Influx (iot_telemetry, 30d) ==="
FLUX='
import "influxdata/influxdb/schema"
schema.tagValues(
  bucket: "'"$BUCKET"'",
  tag: "device_id",
  predicate: (r) => r._measurement == "iot_telemetry",
  start: -30d
)
'

curl -sS -X POST "$URL/api/v2/query?org=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ORG'))")" \
  -H "Authorization: Token $TOKEN" \
  -H "Accept: application/csv" \
  -H "Content-type: application/vnd.flux" \
  --data-binary "$FLUX" | grep -v '^#' | grep -v '^$' || true

if [[ -n "$API_KEY" ]]; then
  echo ""
  echo "=== Registro sma-server (iot_devices.json) ==="
  curl -sS -H "X-API-Key: $API_KEY" "${BASE_URL}/api/v1/iot/devices" | python3 -m json.tool
fi