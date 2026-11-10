# Puesta en marcha en el VPS

Requisitos: Ubuntu 24.04 con Docker y `rclone`, un dominio en Cloudflare y el número de WhatsApp en Meta.

## 1. Cloudflare

- Dominio actual: `PLATAFORMA_DOMINIO=ryjec.com` y `APP_SUBDOMINIO=rycitas`.
  - `rycitas.ryjec.com` es la plataforma: la app web, la API (`API_URL` de la app), `/panel/`, `/admin/` y `/privacidad/`.
  - Cada negocio vive en `<slug>.ryjec.com`, con el subdominio igual a su slug en el panel. Hoy son `glowclinic` y `sonrisawari`.
- DNS, con proxy activado: un registro `A` por subdominio (`rycitas`, `glowclinic`, `sonrisawari`, …) apuntando al VPS, o
  un `A *` si `ryjec.com` no se usa para nada más. Cada negocio nuevo necesita su registro.
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

## 2b. Panel y /admin solo para el equipo (imprescindible)

`/panel/` y `/admin/` exportan y cambian los datos de **todos** los negocios. Además del límite de intentos de la
aplicación (5 por cuenta y 20 por IP por hora), ponerlos detrás de **Cloudflare Zero Trust → Access** (gratis hasta 50
usuarios). Crear una aplicación *Self-hosted* para `rycitas.ryjec.com/panel*` y `rycitas.ryjec.com/admin*`, con una
política *Allow* solo para los correos del equipo y el código de un solo uso por correo. Así, nadie fuera del equipo
llega siquiera al formulario de login.

## 3. Desplegar

```bash
git clone <repositorio> /opt/denticita && cd /opt/denticita/deploy
cp .env.example .env   # completar
./desplegar.sh
docker compose exec web python manage.py createsuperuser
```

`desplegar.sh` respalda la base **antes** de migrar (desde el segundo despliegue), etiqueta cada imagen con la fecha
(`rycitas-web:AAAAMMDDhhmmss`, conserva las 3 últimas) y, si la versión nueva no queda saludable, vuelve sola a la
anterior. Para volver atrás a mano: `./rollback.sh` (la penúltima) o `./rollback.sh <versión>`. El rollback no deshace
migraciones: si una dejó la base incompatible, `./restaurar.sh base-<fecha>.dump.enc` con el respaldo previo. Por eso
las migraciones se escriben compatibles con la versión anterior (agregar primero; quitar en un despliegue posterior).

Panel: `https://rycitas.ryjec.com/panel/` (y `/admin/`). El alta de un consultorio (RF-33) se hace ahí: crear el consultorio con su horario y
tratamientos, y luego su usuario.

### 3b. Servidor compartido (ya hay un Caddy en 80/443)

Cuando el VPS aloja otros sistemas y su propio Caddy ya ocupa los puertos 80 y 443:

1. En `deploy/.env` activar la variante:

   ```
   COMPOSE_FILE=docker-compose.yml:docker-compose.compartido.yml
   WEB_PUERTO_LOCAL=18100
   ```

   El Caddy del compose ya no arranca, Django queda solo en `127.0.0.1:18100` y las imágenes en `deploy/media`. La
   base de datos sigue siendo un contenedor propio sin puerto publicado.
2. Copiar `deploy/caddy-servidor/rycitas.caddy` a `/etc/caddy/sites.d/80-rycitas.caddy`, ajustando los hosts, el
   puerto y la ruta `/opt/rycitas` si cambian. Después validar y recargar, lo que no corta los demás sitios:

   ```bash
   caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
   ```

   Los certificados son automáticos por host. Cada negocio nuevo con subdominio propio se agrega a ese archivo.
3. No hace falta `certs/origen.pem`. El firewall puede quedar como está: el archivo de Caddy reemplaza
   `CF-Connecting-IP` cuando la petición no viene de Cloudflare, así nadie falsifica su IP entrando directo al servidor.

## 4. WhatsApp (Meta), opcional

Por defecto no hace falta: el doctor confirma y recuerda desde su propio WhatsApp. Solo con `VERIFICACION_WHATSAPP=1`:

Webhook: `https://dominio/webhooks/whatsapp`, con el `WHATSAPP_VERIFY_TOKEN` de `.env`, suscrito al campo `messages`.
`WHATSAPP_APP_SECRET` es el secreto de la app de Meta. Sin él, el webhook rechaza todo.

## 5. App Android de producción

- `app_doctor/config/prod.json` ya apunta a `https://rycitas.ryjec.com`.
- Clave de publicación: crearla una vez (`keytool -genkey -v -keystore publicacion.jks -keyalg RSA -keysize 2048
  -validity 10000 -alias rycitas`) y **guardarla fuera del repositorio** con sus claves: sin ella no se puede publicar
  una actualización en Google Play. Localmente, `app_doctor/android/key.properties` con `storeFile=publicacion.jks`,
  `storePassword`, `keyAlias` y `keyPassword`.
- La compilación `--flavor prod --release` se niega a correr sin esa clave o sin `src/prod/google-services.json`.
- En GitHub (Settings → Secrets → Actions): `ANDROID_KEYSTORE_BASE64` (`base64 -w0 publicacion.jks`),
  `ANDROID_KEY_PROPERTIES` y `GOOGLE_SERVICES_PROD`. Sin ellos, el CI prueba todo pero no compila el APK de producción.

## 5. Firebase

- Crear dos proyectos (dev y prod) y colocar `google-services.json` en `app_doctor/android/app/src/{dev,prod}/`.
- Generar una cuenta de servicio del proyecto prod y guardarla en `deploy/secretos/firebase.json`.

## 6. Respaldos y monitoreo

- Monitores externos (UptimeRobot u otro): `https://rycitas.ryjec.com/salud/` (la web y la base) y
  `https://rycitas.ryjec.com/salud/?cola=1`, que además falla si la cola de tareas lleva más de 5 min sin correr
  (pre-reservas sin expirar, recordatorios sin salir). En el servidor, `docker compose ps` muestra `tareas` como
  `unhealthy` en ese caso.

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
