#!/usr/bin/env bash
# Despliega sma-server en red wg-easy (producción Gironasa).
set -euo pipefail

cd "$(dirname "$0")/.."

WG_CONTAINER="${WG_CONTAINER:-wg-easy}"

if ! docker ps --format '{{.Names}}' | grep -qx "$WG_CONTAINER"; then
  echo "ERROR: no está corriendo el contenedor WireGuard '$WG_CONTAINER'."
  echo "  docker ps --format '{{.Names}}' | grep -i wg"
  echo "  Ajusta WG_CONTAINER en .env si el nombre es otro (ej. wg_easy)."
  exit 1
fi

echo "Desplegando sma-server en red de: $WG_CONTAINER"
docker compose up -d --build

echo ""
echo "Comprobación (desde VPS o RPi por VPN):"
echo "  curl -s http://10.8.0.1:8000/health"
echo "  curl -s http://10.8.0.1:8000/ready"