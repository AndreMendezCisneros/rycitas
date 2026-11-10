# Puesta en marcha en el VPS

Requisitos: Ubuntu 24.04 con Docker y `rclone`, un dominio en Cloudflare y el número de WhatsApp en Meta.

## 1. Cloudflare

- DNS, con proxy activado: `A @`, `A *` apuntando al VPS.
- SSL/TLS: modo **Full (strict)** y **Always Use HTTPS**.
- Origin Server: crear un certificado para `dominio` y `*.dominio`; guardarlo en `deploy/certs/origen.pem` y `origen.key`.
- **Cache Rule** obligatoria: Cloudflare no cachea HTML por defecto. Regla «Eligible for cache» + «Use cache-control header»
  para el host `*.dominio`, excluyendo `/api/`, `/webhooks/`, `/c/`, `/cita/` y `/admin/`. En `/public/` solo
  `/public/v1/<slug>/perfil` declara caché; lo demás responde sin ella. El HTML se guarda 5 minutos.
- **Purga automática (opcional)**: un token de API con permiso *Zone → Cache Purge* y el id de la zona en
  `CLOUDFLARE_TOKEN_CACHE` y `CLOUDFLARE_ZONA`. Al guardar un consultorio, un tratamiento o el horario, se borra la copia
  de ese sitio. Sin ellos, los cambios aparecen en hasta 5 minutos.
- **Web Analytics (opcional, sin cookies)**: crear el sitio en Cloudflare y copiar el token a `CLOUDFLARE_ANALYTICS_TOKEN`.
- Turnstile: crear un widget para `*.dominio` y copiar las dos claves a `.env`.

## 2. Firewall del VPS (imprescindible)

El límite de intentos por IP confía en `CF-Connecting-IP`. Si el servidor acepta tráfico directo, cualquiera falsifica
ese encabezado y evade el límite. Abrir el 443 **solo** a Cloudflare, y el 22 solo a tu IP:

```bash
ufw default deny incoming
ufw allow from TU_IP to any port 22
for ip in $(curl -s https://www.cloudflare.com/ips-v4) $(curl -s https://www.cloudflare.com/ips-v6); do
  ufw allow from "$ip" to any port 443 proto tcp
done
ufw enable
```

Ojo: Docker publica puertos saltándose `ufw` por defecto. Hay que cerrar eso también: restringir en el firewall del
proveedor del VPS, o aplicar las reglas en la cadena `DOCKER-USER`. Comprobar desde fuera con `curl -k https://IP_DEL_VPS`.

## 3. Desplegar

```bash
git clone <repositorio> /opt/denticita && cd /opt/denticita/deploy
cp .env.example .env   # completar
./desplegar.sh
docker compose exec web python manage.py createsuperuser
```

Panel: `https://dominio/admin/`. El alta de un consultorio (RF-33) se hace ahí: crear el consultorio con su horario y
tratamientos, y luego su usuario.

## 4. WhatsApp (Meta), opcional

Por defecto no hace falta: el doctor confirma y recuerda desde su propio WhatsApp. Solo con `VERIFICACION_WHATSAPP=1`:

Webhook: `https://dominio/webhooks/whatsapp`, con el `WHATSAPP_VERIFY_TOKEN` de `.env`, suscrito al campo `messages`.
`WHATSAPP_APP_SECRET` es el secreto de la app de Meta. Sin él, el webhook rechaza todo.

## 5. Firebase

- Crear dos proyectos (dev y prod) y colocar `google-services.json` en `app_doctor/android/app/src/{dev,prod}/`.
- Generar una cuenta de servicio del proyecto prod y guardarla en `deploy/secretos/firebase.json`.

## 6. Respaldos y monitoreo

```bash
rclone config                # crear el remoto «r2» (Cloudflare R2, API S3)
crontab -e                   # 0 4 * * * /opt/denticita/deploy/respaldar.sh >> /var/log/denticita-respaldo.log 2>&1
```

- **Simulacro mensual** (RNF-06): `./simulacro_restauracion.sh` restaura la última copia en una base temporal, compara
  conteos y la borra, sin tocar producción. Para migrar de servidor: `./restaurar.sh base-<fecha>.dump.enc`.
- **Monitor externo**: UptimeRobot (gratis, cada 5 min) contra `https://dominio/salud/`.

## 7. App del doctor

```bash
cd app_doctor
flutter build apk --flavor prod --release --dart-define-from-file=config/prod.json   # APK firmado: ver android/key.properties
flutter build web --release --dart-define-from-file=config/prod.json                 # copiar build/web a deploy/app_web
```

Antes, editar `config/prod.json` con el dominio real. La app web usa `app.dominio`, igual que la API.
