#!/usr/bin/env bash
# Encola un comando ON/OFF de prueba.
# Uso: bash scripts/test_command.sh ESP-ACA704305E20 1 true
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-}"
OUTPUT="${2:-1}"
STATE="${3:-true}"

if [[ -f .env ]]; then set -a; source .env; set +a; fi
API="${SMA_API_KEY:-}"
URL="${TEST_API_URL:-http://10.8.0.1:8000}"

if [[ -z "$DEVICE" || -z "$API" ]]; then
  echo "Uso: bash scripts/test_command.sh ESP-XXXXXXXXXXXX [salida 1-4] [true|false]"
  exit 1
fi

echo "POST $URL/api/v1/iot/commands"
curl -sS -X POST "$URL/api/v1/iot/commands" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API" \
  -d "{\"device_id\":\"$DEVICE\",\"action\":\"set_output\",\"output\":$OUTPUT,\"state\":$STATE}"
echo ""
echo ""
echo "Pendientes (debería vaciarse en ~1s si iot-gateway en RPi está activo):"
sleep 2
curl -sS -H "X-API-Key: $API" "$URL/api/v1/iot/commands/pending"
echo ""