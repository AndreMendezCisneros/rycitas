#!/usr/bin/env bash
# Vuelve a una versión anterior de la aplicación: ./rollback.sh            (la penúltima desplegada)
#                                                 ./rollback.sh 20261110153000
# Solo cambia el código (imagen). La base queda como está: si una migración la dejó incompatible, restaurar el
# respaldo que desplegar.sh hizo antes de migrar (./restaurar.sh base-<fecha>.dump.enc).
set -euo pipefail
cd "$(dirname "$0")"

HISTORIAL=.versiones
destino="${1:-$(tail -n 2 "$HISTORIAL" 2>/dev/null | head -n 1)}"
[ -n "$destino" ] || { echo "No hay una versión anterior en $HISTORIAL"; exit 1; }
docker image inspect "rycitas-web:$destino" >/dev/null 2>&1 || {
  echo "La imagen rycitas-web:$destino ya no existe. Disponibles:"
  docker images rycitas-web --format '  {{.Tag}}'
  exit 1
}

echo "Volviendo a rycitas-web:$destino..."
VERSION="$destino" docker compose up -d --no-build web tareas
for _ in $(seq 1 30); do
  if [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q web)")" = "healthy" ]; then
    echo "$destino" >> "$HISTORIAL"
    echo "Listo: en servicio $destino"
    exit 0
  fi
  sleep 3
done
echo "No quedó saludable. Revisa: docker compose logs web"
exit 1
