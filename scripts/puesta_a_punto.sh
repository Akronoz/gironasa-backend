#!/usr/bin/env bash
# Diagnóstico y comprobación del circuito IoT → Influx (ejecutar en el VPS).
set -euo pipefail

cd "$(dirname "$0")/.."
API_KEY="${SMA_API_KEY:-}"
WG_NAME="${WG_CONTAINER:-wg-easy}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  API_KEY="${SMA_API_KEY:-}"
  WG_NAME="${WG_CONTAINER:-wg-easy}"
fi

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  PUESTA A PUNTO — sma-server + Influx IoT               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "── 1. WireGuard (wg-easy) ──"
docker ps --format '  {{.Names}}  {{.Status}}' | grep -i wg || echo "  ¡No hay contenedor wg!"
if docker ps --format '{{.Names}}' | grep -qx "$WG_NAME"; then
  echo "  OK: $WG_NAME en marcha"
else
  echo "  ERROR: falta '$WG_NAME'. Ajusta WG_CONTAINER en .env"
fi

echo ""
echo "── 2. sma-server ──"
if docker ps --format '{{.Names}}' | grep -qx sma-server; then
  docker ps --filter name=sma-server --format '  {{.Names}}  {{.Status}}  ports={{.Ports}}'
  echo "  NetworkMode=$(docker inspect sma-server --format '{{.HostConfig.NetworkMode}}')"
else
  echo "  ERROR: sma-server no está corriendo"
fi

echo ""
echo "── 3. API por VPN (10.8.0.1:8000) — lo que usa la RPi ──"
if curl -sf http://10.8.0.1:8000/health >/dev/null; then
  curl -s http://10.8.0.1:8000/health
  echo ""
  echo "  OK health"
else
  echo "  FALLO — la RPi no puede enviar telemetría"
  echo "  Arreglo: bash deploy/up.sh"
fi

echo ""
echo "── 4. Variables Influx en el contenedor ──"
docker inspect sma-server --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
  | grep -E '^INFLUX_|^SMA_API_KEY' \
  | while IFS= read -r line; do
      k="${line%%=*}"
      v="${line#*=}"
      if [[ "$k" == *TOKEN* || "$k" == *KEY* ]]; then
        echo "  $k=${v:0:4}… (len ${#v})"
      else
        echo "  $line"
      fi
    done || echo "  (sin contenedor)"

echo ""
echo "── 5. Puntos temperature_1 en Influx (24h) ──"
if [[ -f scripts/check_iot_influx.sh ]]; then
  bash scripts/check_iot_influx.sh 2>/dev/null | tail -20 || true
fi

echo ""
echo "── 6. Prueba escritura IoT (opcional) ──"
if [[ -n "$API_KEY" ]] && curl -sf http://10.8.0.1:8000/health >/dev/null; then
  HTTP=$(curl -s -o /tmp/iot-test.json -w "%{http_code}" \
    -X POST http://10.8.0.1:8000/api/v1/iot/telemetry \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $API_KEY" \
    -d '{"events":[{"device_id":"TEST-PING","metric":"temperature_1","channel":"1","value":42.0,"received_at":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}]}')
  echo "  POST telemetría test → HTTP $HTTP  $(cat /tmp/iot-test.json 2>/dev/null)"
else
  echo "  Omitido (falta SMA_API_KEY en entorno o API caído)"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "INFLUX DATA EXPLORER — gráfica temperatura"
echo "══════════════════════════════════════════════════════════"
echo "  Bucket:      sma"
echo "  Measurement: iot_telemetry"
echo "  Field:       value"
echo "  Tag metric:  temperature_1"
echo "  Tag device:  ESP-ACA704305E20  (tu serial)"
echo "  Rango:       Last 1 hour (o 6 hours)"
echo ""
echo "Flux (pegar en Script Editor):"
cat <<'FLUX'

from(bucket: "sma")
  |> range(start: -6h)
  |> filter(fn: (r) => r._measurement == "iot_telemetry")
  |> filter(fn: (r) => r._field == "value")
  |> filter(fn: (r) => r.metric == "temperature_1")
  |> filter(fn: (r) => r.device_id == "ESP-ACA704305E20")
  |> aggregateWindow(every: 1m, fn: mean, createEmpty: false)

FLUX
echo ""
echo "Si count() = 1 → casi no llega telemetría desde la RPi."
echo "Si count() > 50 → deberías ver curva (Visualization: Graph)."
echo "══════════════════════════════════════════════════════════"