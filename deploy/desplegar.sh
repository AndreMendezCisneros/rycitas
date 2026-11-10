#!/usr/bin/env bash
# Despliegue con un comando (RNF-13): ./desplegar.sh
#
# 1. Construye una imagen nueva con etiqueta de fecha (rycitas-web:AAAAMMDDhhmmss); la anterior se conserva.
# 2. check --deploy con la imagen nueva: si falta un secreto, no se despliega.
# 3. Respaldo cifrado ANTES de migrar (respaldar.sh). Solo el primer despliegue, sin datos, lo omite.
# 4. Migra, programa las tareas y levanta la versión nueva.
# 5. Si no queda saludable, vuelve sola a la versión anterior y dice qué respaldo restaurar si hace falta.
#
# Las migraciones deben ser compatibles con la versión anterior (agregar columnas con valor por defecto; quitar en un
# despliegue posterior): mientras migra sigue atendiendo la versión anterior, y el rollback no deshace migraciones.
set -euo pipefail
cd "$(dirname "$0")"

test -f .env || { echo "Falta deploy/.env (ver .env.example)"; exit 1; }
test -f certs/origen.pem || { echo "Falta deploy/certs/origen.pem (ver deploy/README.md)"; exit 1; }
mkdir -p app_web secretos

HISTORIAL=.versiones          # una versión desplegada con éxito por línea; la última es la actual
anterior="$(tail -n 1 "$HISTORIAL" 2>/dev/null || true)"
export VERSION="$(date -u +%Y%m%d%H%M%S)"
echo "Versión nueva: $VERSION${anterior:+ (actual: $anterior)}"

docker compose build web
docker compose up -d db
# El chequeo falla si falta un secreto: mejor no desplegar que desplegar sin protección.
docker compose run --rm --no-deps web python manage.py check --deploy --fail-level ERROR

if [ -n "$anterior" ]; then
  echo "Respaldo antes de migrar..."
  ./respaldar.sh
elif [ "${SIN_RESPALDO:-}" != "1" ]; then
  echo "Primer despliegue: no hay datos que respaldar (para omitir este aviso: SIN_RESPALDO=1)."
fi

docker compose run --rm web python manage.py migrate --noinput
docker compose run --rm web python manage.py programar_tareas
docker compose up -d --remove-orphans

echo "Esperando a que el servicio responda..."
for _ in $(seq 1 30); do
  if [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q web)")" = "healthy" ]; then
    echo "$VERSION" >> "$HISTORIAL"
    # Conserva las 3 últimas imágenes para poder volver atrás (./rollback.sh).
    docker images rycitas-web --format '{{.Tag}}' | sort -r | tail -n +4 | xargs -r -I{} docker rmi "rycitas-web:{}" >/dev/null || true
    docker image prune -f >/dev/null
    echo "Listo: $VERSION"
    exit 0
  fi
  sleep 3
done

echo "El servicio no quedó saludable. Revisa: docker compose logs web"
if [ -n "$anterior" ]; then
  echo "Volviendo a la versión anterior ($anterior)..."
  VERSION="$anterior" docker compose up -d --no-build web tareas
  echo "Si la migración dejó la base incompatible con $anterior, restaura el respaldo recién hecho:"
  echo "  rclone ls \$RCLONE_DESTINO | sort | tail -n 2   # el más reciente"
  echo "  ./restaurar.sh base-<fecha>.dump.enc"
fi
exit 1
