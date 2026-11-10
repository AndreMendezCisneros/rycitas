#!/usr/bin/env bash
# Simulacro mensual de restauración (mejora 13 del análisis RYJEC). NO toca la base de producción:
# restaura la última copia en una base temporal, compara conteos y la borra al terminar.
#   ./simulacro_restauracion.sh                 # la copia más reciente
#   ./simulacro_restauracion.sh base-XXXX.dump.enc
# En cron, el día 1 de cada mes:
#   0 5 1 * * /opt/denticita/deploy/simulacro_restauracion.sh >> /var/log/denticita-simulacro.log 2>&1
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
export VERSION="${VERSION:-$(tail -n 1 .versiones 2>/dev/null || echo actual)}"

: "${RESPALDO_CLAVE:?Falta RESPALDO_CLAVE}"
: "${RCLONE_DESTINO:?Falta RCLONE_DESTINO}"

archivo="${1:-$(rclone lsf "$RCLONE_DESTINO" --include 'base-*.dump.enc' | sort | tail -n 1)}"
[ -n "$archivo" ] || { echo "No hay copias en $RCLONE_DESTINO"; exit 1; }
temporal="simulacro_$(date -u +%Y%m%d%H%M%S)"
inicio=$(date +%s)

psql_db() { docker compose exec -T db psql -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 -tA "$@"; }
limpiar() { psql_db -d postgres -c "DROP DATABASE IF EXISTS $temporal" >/dev/null || true; }
trap limpiar EXIT

echo "Simulacro con $archivo en la base temporal $temporal"
psql_db -d postgres -c "CREATE DATABASE $temporal" >/dev/null
rclone cat "$RCLONE_DESTINO/$archivo" \
  | openssl enc -d -aes-256-cbc -pbkdf2 -pass env:RESPALDO_CLAVE \
  | docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$temporal" --no-owner --exit-on-error

fallos=0
for tabla in consultorios_consultorio consultorios_profesional consultorios_usuario citas_paciente citas_cita \
             agenda_tratamiento agenda_horariosemanal; do
  copia=$(psql_db -d "$temporal" -c "SELECT count(*) FROM $tabla")
  actual=$(psql_db -d "$POSTGRES_DB" -c "SELECT count(*) FROM $tabla")
  estado="ok"
  # La copia es de hasta 24 h antes: puede tener menos filas, nunca muchas menos ni más.
  if [ "$copia" -gt "$actual" ] || { [ "$actual" -gt 20 ] && [ "$copia" -lt $((actual * 8 / 10)) ]; }; then
    estado="REVISAR"; fallos=$((fallos + 1))
  fi
  printf '%-30s copia=%-8s actual=%-8s %s\n' "$tabla" "$copia" "$actual" "$estado"
done

# Las restricciones que protegen la agenda deben venir en la copia.
if [ "$(psql_db -d "$temporal" -c "SELECT count(*) FROM pg_constraint WHERE conname = 'cita_sin_cruces'")" != "1" ]; then
  echo "Falta la restricción cita_sin_cruces"; fallos=$((fallos + 1))
fi
pendientes=$(docker compose exec -T -e POSTGRES_DB="$temporal" web python manage.py showmigrations --plan \
  | grep -c '\[ \]' || true)
echo "Migraciones sin aplicar en la copia: $pendientes (normal si hubo un despliegue después del respaldo)"

echo "Duración: $(( $(date +%s) - inicio )) s"
if [ "$fallos" -gt 0 ]; then
  echo "SIMULACRO CON OBSERVACIONES ($fallos)"; exit 1
fi
echo "SIMULACRO CORRECTO"
