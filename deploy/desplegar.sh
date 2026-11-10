#!/usr/bin/env bash
# Despliegue con un comando (RNF-13): ./desplegar.sh
set -euo pipefail
cd "$(dirname "$0")"

test -f .env || { echo "Falta deploy/.env (ver .env.example)"; exit 1; }
test -f certs/origen.pem || { echo "Falta deploy/certs/origen.pem (ver deploy/README.md)"; exit 1; }
mkdir -p app_web secretos

docker compose build web tareas
docker compose up -d db
# El chequeo falla si falta un secreto: mejor no desplegar que desplegar sin protección.
docker compose run --rm --no-deps web python manage.py check --deploy --fail-level ERROR
docker compose run --rm web python manage.py migrate --noinput
docker compose run --rm web python manage.py programar_tareas
docker compose up -d --remove-orphans
docker image prune -f >/dev/null

echo "Esperando a que el servicio responda..."
for _ in $(seq 1 30); do
  if [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q web)")" = "healthy" ]; then
    echo "Listo."
    exit 0
  fi
  sleep 3
done
echo "El servicio no quedó saludable. Revisa: docker compose logs web"
exit 1
