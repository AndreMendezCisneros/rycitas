#!/usr/bin/env bash
# Restaura una copia: ./restaurar.sh base-20261107T040000Z.dump.enc
# REEMPLAZA los datos actuales. Sirve para el simulacro mensual y para migrar de servidor (RNF-06, RNF-14).
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a

archivo="${1:?Uso: ./restaurar.sh <archivo>. Ver copias con: rclone ls $RCLONE_DESTINO}"
read -r -p "Esto reemplaza la base «$POSTGRES_DB» de este servidor. Escribe RESTAURAR para continuar: " respuesta
[ "$respuesta" = "RESTAURAR" ] || { echo "Cancelado."; exit 1; }

docker compose up -d db
docker compose stop web tareas
rclone cat "$RCLONE_DESTINO/$archivo" \
  | openssl enc -d -aes-256-cbc -pbkdf2 -pass env:RESPALDO_CLAVE \
  | docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner

medios="${archivo/base-/media-}"
medios="${medios/.dump.enc/.tar.enc}"
if rclone lsf "$RCLONE_DESTINO/$medios" >/dev/null 2>&1; then
  docker compose up -d web
  rclone cat "$RCLONE_DESTINO/$medios" \
    | openssl enc -d -aes-256-cbc -pbkdf2 -pass env:RESPALDO_CLAVE \
    | docker compose exec -T web tar -C /media -xf -
fi

docker compose up -d
echo "Restaurado. Verifica el sitio y la app antes de dar por bueno el simulacro."
