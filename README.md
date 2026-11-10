# RyCitas

Reserva de citas para negocios con agenda: consultorios dentales, barberías, peluquerías, estética, salud y
veterinarias. Un cliente reserva en la web en menos de un minuto, sin crear cuenta, y el negocio la confirma desde su
celular por su propio WhatsApp. El costo de operación es menor a S/ 50 al mes, sin mensajes pagados.

Cada negocio puede tener **su propio sitio web completo**. RyCitas entra cuando el cliente toca «Agendar cita»: la
reserva se abre encima del sitio. Además, `negocio.rycitas.com/reservar/` es un enlace directo para compartir. Ver
[`docs/SITIOS_PROPIOS.md`](docs/SITIOS_PROPIOS.md).

Cada negocio se crea desde el **panel de la plataforma** eligiendo su tipo. El tipo precarga los servicios, el horario
y el vocabulario: «cortes» y «barbero» en una barbería, «tratamientos» y «doctora» en un dental. La sección 8 de
[`docs/ANALISIS.md`](docs/ANALISIS.md) lo resume.

| Carpeta | Qué hay |
| --- | --- |
| `backend/` | Monolito Django + Django Ninja: sitio por subdominio, `/public/v1`, `/api/v1`, panel (y webhook de WhatsApp, opcional) |
| `app_doctor/` | App RyCitas (Flutter) del negocio: Android, y web como respaldo |
| `sitios/` | Código de los sitios propios de cada negocio (por ejemplo, `visage-artisan-hub`); se compilan con `scripts/sitio.ps1` |
| `deploy/` | Docker Compose, Caddy, despliegue, respaldos. Guía en [`deploy/README.md`](deploy/README.md) |
| `docs/ANALISIS.md` | Hallazgos del análisis, decisiones tomadas, trazabilidad y lo que falta verificar |

## Probarlo en local (Windows)

Necesita Python 3.12 y PostgreSQL instalado. Usa tu PostgreSQL (puerto 5432) con su propia base y usuario
`denticita` / `denticita`, sin tocar tus otras bases. Créalos una vez (pide la clave de `postgres`):

```powershell
psql -U postgres -h localhost -c "CREATE ROLE denticita LOGIN PASSWORD 'denticita' CREATEDB;" -c "CREATE DATABASE denticita OWNER denticita;"
```

Con `$env:DENTICITA_PG_PORT = "5544"` usa en cambio un clúster aparte en `%LOCALAPPDATA%\denticita`.

```powershell
.\scripts\dev.ps1 setup   # una sola vez
.\scripts\dev.ps1 run
```

- Sitio propio de demostración: <http://glowclinic.localhost:8000> (botón «Agendar») y su enlace directo
  <http://glowclinic.localhost:8000/reservar/>. App: `recepcion@glowclinic.test`
- Landing de demostración: <http://sonrisa-wari.localhost:8000>. La reserva queda «por confirmar» y el doctor la confirma
  desde la app, que abre WhatsApp con el mensaje listo. Con `VERIFICACION_WHATSAPP=1` vuelve el flujo con código y su
  simulador
- Panel de la plataforma (crear y controlar negocios): <http://localhost:8000/panel/> con `admin@denticita.test`.
  El admin de Django (`/admin/`) queda solo como respaldo técnico
- Doctor: `doctora@sonrisawari.test`
- Clave de ambos: `demo-denticita-2026`

La app del doctor, en otra terminal:

```powershell
cd app_doctor
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome --dart-define-from-file=config/web_dev.json
```

En un celular o emulador Android: `flutter run --flavor dev --dart-define-from-file=config/dev.json`.
`config/dev.json` apunta a `10.0.2.2`, que es tu PC vista desde el emulador; para un celular físico cambia esa IP.

## Pruebas

```powershell
.\scripts\dev.ps1 test            # backend, contra PostgreSQL real
cd app_doctor; flutter test       # app
k6 run scripts/carga.js           # carga del RNF-03
```

## Sin Firebase ni Meta

Todo funciona sin configurarlos, para poder desarrollar: sin Firebase la app no recibe push y se actualiza cada 30 s;
sin Meta se usa el botón de simulación, que solo existe con `DJANGO_DEBUG=1`. En producción, `manage.py check --deploy`
impide desplegar si faltan los secretos.
