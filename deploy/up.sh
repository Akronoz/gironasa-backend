#!/usr/bin/env bash
# Despliega sma-server en red wg-easy (producción Gironasa).
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

WG_CONTAINER="${WG_CONTAINER:-wg-easy}"

echo "=== Contenedores WireGuard ==="
docker ps --format '{{.Names}}' | grep -i wg || true
echo ""

if ! docker ps --format '{{.Names}}' | grep -qx "$WG_CONTAINER"; then
  echo "ERROR: no está corriendo '$WG_CONTAINER'."
  echo "Ajusta WG_CONTAINER en .env (nombre exacto de docker ps)."
  exit 1
fi

echo "=== Recrear sma-server en red de: $WG_CONTAINER ==="
docker rm -f sma-server 2>/dev/null || true
docker compose up -d --build

echo "Esperando arranque uvicorn..."
sleep 4

echo ""
echo "=== Estado ==="
docker ps -a --filter name=sma-server --format 'table {{.Names}}\t{{.Status}}'
echo "NetworkMode=$(docker inspect sma-server --format '{{.HostConfig.NetworkMode}}' 2>/dev/null || echo '?')"

echo ""
echo "=== Logs sma-server (últimas 15 líneas) ==="
docker logs sma-server --tail 15 2>&1 || true

_probe() {
  local label="$1"
  local cmd="$2"
  echo -n "  $label → "
  if eval "$cmd" >/dev/null 2>&1; then
    eval "$cmd" 2>/dev/null | head -c 200
    echo ""
    echo "  OK"
    return 0
  fi
  echo "FALLO"
  return 1
}

echo ""
echo "=== Health checks ==="
OK_ANY=0
_probe "localhost:8000 (dentro sma-server)" \
  "docker exec sma-server python -c \"import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).read().decode())\"" \
  && OK_ANY=1 || true

_probe "localhost:8000 (dentro $WG_CONTAINER)" \
  "docker exec $WG_CONTAINER wget -qO- http://127.0.0.1:8000/health 2>/dev/null" \
  && OK_ANY=1 || true

_probe "10.8.0.1:8000 (desde host VPS)" \
  "curl -sf --connect-timeout 3 http://10.8.0.1:8000/health" \
  && OK_ANY=1 || true

echo ""
if [[ "$OK_ANY" -eq 1 ]]; then
  echo "sma-server responde. Prueba desde la RPi:"
  echo "  curl -s http://10.8.0.1:8000/health"
else
  echo "ERROR: sma-server no responde en ningún check."
  echo "Revisa: docker logs sma-server --tail 50"
  echo "¿.env tiene SMA_API_KEY, INFLUX_TOKEN, INFLUX_ORG, INFLUX_BUCKET?"
  exit 1
fi