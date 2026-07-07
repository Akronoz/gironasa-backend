#!/usr/bin/env bash
# Borra dispositivos IoT (Influx + data/iot_devices.json).
# Uso:
#   bash scripts/purge_iot_device.sh homeassistant niquel
#   bash scripts/purge_iot_device.sh --influx-only homeassistant
#   bash scripts/purge_iot_device.sh --registry-only niquel

set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 "$(dirname "$0")/purge_iot_device.py" "$@"