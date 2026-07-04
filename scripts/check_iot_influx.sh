#!/usr/bin/env bash
# Comprueba si hay telemetría IoT en InfluxDB (temperatura, entradas).
# Uso en el VPS:
#   cd ~/gironasa/sma-server && bash scripts/check_iot_influx.sh

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

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: falta INFLUX_TOKEN en .env"
  exit 1
fi

echo "=== Telemetría IoT en Influx ==="
echo "Org: $ORG  Bucket: $BUCKET  URL: $URL"
echo ""

FLUX='
from(bucket: "'"$BUCKET"'")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "iot_telemetry")
  |> filter(fn: (r) => r._field == "value")
  |> group(columns: ["device_id", "metric"])
  |> count()
  |> sort(columns: ["_value"], desc: true)
'

echo "--- Puntos por dispositivo y métrica (últimas 24h) ---"
curl -sS -X POST "$URL/api/v2/query?org=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ORG'))")" \
  -H "Authorization: Token $TOKEN" \
  -H "Accept: application/csv" \
  -H "Content-type: application/vnd.flux" \
  --data-binary "$FLUX" | head -40

echo ""
echo "--- Últimas 5 lecturas temperature_1 ---"
FLUX2='
from(bucket: "'"$BUCKET"'")
  |> range(start: -6h)
  |> filter(fn: (r) => r._measurement == "iot_telemetry")
  |> filter(fn: (r) => r._field == "value")
  |> filter(fn: (r) => r.metric == "temperature_1")
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: 5)
'

curl -sS -X POST "$URL/api/v2/query?org=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$ORG'))")" \
  -H "Authorization: Token $TOKEN" \
  -H "Accept: application/csv" \
  -H "Content-type: application/vnd.flux" \
  --data-binary "$FLUX2"

echo ""
echo "Si no hay filas: el gateway no está llegando al sma-server o el ESP no publica MQTT."
echo "Si hay 1-2 puntos: acaba de empezar; espera unos minutos con gateway OK."
echo ""
echo "En la UI de Influx Data Explorer:"
echo "  measurement = iot_telemetry  (NO temperature_1)"
echo "  field       = value"
echo "  filter tag  metric = temperature_1"