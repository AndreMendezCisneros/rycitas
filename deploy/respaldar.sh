#!/usr/bin/env bash
# Copia diaria cifrada fuera del servidor (RNF-06). En cron:
#   0 4 * * * /opt/denticita/deploy/respaldar.sh >> /var/log/denticita-respaldo.log 2>&1
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
# Desde cron no llega VERSION: se usa la imagen en servicio (la última de .versiones).
export VERSION="${VERSION:-$(tail -n 1 .versiones 2>/dev/null || echo actual)}"

: "${RESPALDO_CLAVE:?Falta RESPALDO_CLAVE}"
: "${RCLONE_DESTINO:?Falta RCLONE_DESTINO}"
fecha="$(date -u +%Y%m%dT%H%M%SZ)"

# Cifrado aquí porque la copia lleva nombres y celulares (Ley 29733) y sale a un tercero.
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc \
  | openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:RESPALDO_CLAVE \
  | rclone rcat "$RCLONE_DESTINO/base-$fecha.dump.enc"

# Con la web en marcha se lee de ella; si no (antes de levantarla), con un contenedor de un solo uso.
if [ -n "$(docker compose ps --status running -q web)" ]; then
  medios=(docker compose exec -T web)
else
  medios=(docker compose run --rm --no-deps -T web)
fi
"${medios[@]}" tar -C /media -cf - . \
  | openssl enc -aes-256-cbc -pbkdf2 -salt -pass env:RESPALDO_CLAVE \
  | rclone rcat "$RCLONE_DESTINO/media-$fecha.tar.enc"

rclone delete --min-age 30d "$RCLONE_DESTINO"
echo "$fecha respaldo completo"
