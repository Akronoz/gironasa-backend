#!/usr/bin/env bash
# Lista device_id con datos reales en Influx, registro y machines config.
# Uso: cd ~/gironasa/sma-server && bash scripts/list_iot_devices.sh

set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source "$(dirname "$0")/_iot_scripts_lib.sh"
_iot_load_env

ORG="${INFLUX_ORG:-Gironasa}"
BUCKET="${INFLUX_BUCKET:-sma}"
URL="${INFLUX_URL:-http://127.0.0.1:8086}"
TOKEN="${INFLUX_TOKEN:-}"
API_KEY="${SMA_API_KEY:-}"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: falta INFLUX_TOKEN en .env"
  exit 1
fi

echo "=== device_id con puntos en Influx (iot_telemetry, 30d) ==="
FLUX='
from(bucket: "'"$BUCKET"'")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "iot_telemetry")
  |> group(columns: ["device_id"])
  |> count()
  |> group()
  |> sort(columns: ["_value"], desc: true)
'

curl -sS -X POST "$URL/api/v2/query?org=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ORG'))")" \
  -H "Authorization: Token $TOKEN" \
  -H "Accept: application/csv" \
  -H "Content-type: application/vnd.flux" \
  --data-binary "$FLUX" | grep -v '^#' | grep -v '^$' || echo "(ninguno)"

echo ""
echo "=== Equipos en machines_config.json (lo que muestra la web) ==="
if [[ -f data/machines_config.json ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
raw = json.loads(Path("data/machines_config.json").read_text(encoding="utf-8"))
for m in raw.get("machines", []):
    did = m.get("device_id") or m.get("deviceId") or m.get("id")
    name = m.get("name") or "(sin nombre)"
    print(f"  - {did}  name={name!r}")
ambient = raw.get("ambientTemperatureSource")
if ambient:
    print(f"  ambientTemperatureSource -> {ambient}")
PY
else
  echo "  (no existe data/machines_config.json)"
fi

if [[ -n "$API_KEY" ]]; then
  echo ""
  echo "=== Registro sma-server (iot_devices.json) ==="
  if BASE_URL="$(resolve_sma_base_url)"; then
    echo "API: $BASE_URL"
    curl -sS -H "X-API-Key: $API_KEY" "${BASE_URL}/api/v1/iot/devices" | python3 -m json.tool
  elif [[ -f data/iot_devices.json ]]; then
    python3 -m json.tool data/iot_devices.json
  fi
fi

echo ""
echo "Nota: el explorador de Influx puede seguir sugiriendo tags antiguos en el autocompletado"
echo "      aunque ya no haya puntos. La tabla de arriba cuenta datos reales."