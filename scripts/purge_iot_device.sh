#!/usr/bin/env bash
# Borra un dispositivo IoT del registro (iot_devices.json) y su telemetría en Influx.
# Uso:
#   cd ~/gironasa/sma-server && bash scripts/purge_iot_device.sh ESP-AABBCCDDEEFF
#   bash scripts/purge_iot_device.sh homeassistant niquel
#
# sma-server en wg-easy: API en http://10.8.0.1:8000 (auto-detectado).
# Solo Influx (sin API): bash scripts/purge_iot_device.sh --influx-only homeassistant

set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source "$(dirname "$0")/_iot_scripts_lib.sh"
_iot_load_env

INFLUX_ONLY=0
DEVICE_IDS=()
for arg in "$@"; do
  if [[ "$arg" == "--influx-only" ]]; then
    INFLUX_ONLY=1
  else
    DEVICE_IDS+=("$arg")
  fi
done

if [[ ${#DEVICE_IDS[@]} -lt 1 ]]; then
  echo "Uso: $0 [--influx-only] <device_id> [device_id ...]"
  exit 1
fi

API_KEY="${SMA_API_KEY:-}"
BASE_URL=""
if [[ "$INFLUX_ONLY" -eq 0 ]]; then
  if [[ -z "$API_KEY" ]]; then
    echo "ERROR: falta SMA_API_KEY en .env"
    exit 1
  fi
  if ! BASE_URL="$(resolve_sma_base_url)"; then
    echo "WARN: sma-server no responde en 10.8.0.1:8000 ni 127.0.0.1:8000"
    echo "      Usa --influx-only o export SMA_BASE_URL=http://10.8.0.1:8000"
    exit 1
  fi
  echo "API: $BASE_URL"
fi

for device_id in "${DEVICE_IDS[@]}"; do
  echo "==> Purging $device_id"
  if [[ "$INFLUX_ONLY" -eq 1 ]]; then
    purge_device_influx_direct "$device_id"
    echo " (Influx OK)"
    continue
  fi

  if ! curl -sf --connect-timeout 5 \
    -X DELETE \
    -H "X-API-Key: $API_KEY" \
    "${BASE_URL}/api/v1/iot/devices/${device_id}?purge_influx=true"; then
    echo ""
    echo "WARN: API falló; intentando borrado directo en Influx..."
    purge_device_influx_direct "$device_id"
    echo " (Influx OK; revisa data/iot_devices.json si el device seguía registrado)"
  fi
  echo ""
done

echo "Listo."