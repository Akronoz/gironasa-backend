#!/usr/bin/env bash
# Borra un dispositivo IoT del registro (iot_devices.json) y su telemetría en Influx.
# Uso:
#   cd ~/gironasa/sma-server && bash scripts/purge_iot_device.sh ESP-AABBCCDDEEFF
#   bash scripts/purge_iot_device.sh ESP-AAA ESP-BBB   # varios

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <device_id> [device_id ...]"
  exit 1
fi

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

API_KEY="${SMA_API_KEY:-}"
BASE_URL="${SMA_BASE_URL:-http://127.0.0.1:8000}"

if [[ -z "$API_KEY" ]]; then
  echo "ERROR: falta SMA_API_KEY en .env"
  exit 1
fi

for device_id in "$@"; do
  echo "==> Purging $device_id"
  curl -sS -X DELETE \
    -H "X-API-Key: $API_KEY" \
    "${BASE_URL}/api/v1/iot/devices/${device_id}?purge_influx=true"
  echo ""
done

echo "Listo. Los equipos ya no aparecerán en la web si no están en machines config."