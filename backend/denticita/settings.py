"""Configuración única del monolito. Todo lo que cambia por entorno viene de variables."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def _bool(nombre: str, defecto: bool = False) -> bool:
    return os.environ.get(nombre, "1" if defecto else "0").lower() in {"1", "true", "yes", "si"}


DEBUG = _bool("DJANGO_DEBUG")
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "solo-para-desarrollo-no-usar-en-produccion" if DEBUG else "")
JWT_SECRET = os.environ.get("JWT_SECRET", SECRET_KEY)

# Dominio de la plataforma: cada consultorio vive en <slug>.<dominio>.
PLATAFORMA_DOMINIO = os.environ.get("PLATAFORMA_DOMINIO", "localhost")
# Subdominio de la plataforma: app web, API, panel y política de privacidad (producción: rycitas.ryjec.com).
APP_SUBDOMINIO = os.environ.get("APP_SUBDOMINIO", "app")
SUBDOMINIOS_RESERVADOS = {"www", "app", "api", "admin", "citas", "static", "media", "rycitas", APP_SUBDOMINIO}
ALLOWED_HOSTS = [PLATAFORMA_DOMINIO, f".{PLATAFORMA_DOMINIO}"]
if DEBUG:
    # HOSTS_DESARROLLO: la IP de la PC en la red local, para probar la app en un teléfono real (scripts/dev.ps1).
    ALLOWED_HOSTS += ["127.0.0.1", *[h.strip() for h in os.environ.get("HOSTS_DESARROLLO", "").split(",") if h.strip()]]
CSRF_TRUSTED_ORIGINS = [f"https://{PLATAFORMA_DOMINIO}", f"https://*.{PLATAFORMA_DOMINIO}"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    "django_q",
    "consultorios",
    "agenda",
    "citas",
    "mensajeria",
    "sitio.apps.SitioConfig",
    "panel",
    "clientes",
]

MIDDLEWARE = [
    "denticita.contexto.ContextoMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "sitio.seguridad.PoliticaContenidoMiddleware",
    "sitio.middleware.ConsultorioMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
if DEBUG:
    MIDDLEWARE.insert(0, "denticita.cors_dev.CorsDesarrolloMiddleware")

ROOT_URLCONF = "denticita.urls"
WSGI_APPLICATION = "denticita.wsgi.application"
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": os.environ.get("POSTGRES_HOST", "localhost"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "NAME": os.environ.get("POSTGRES_DB", "denticita"),
        "USER": os.environ.get("POSTGRES_USER", "denticita"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", ""),
        "CONN_MAX_AGE": 60,
        "CONN_HEALTH_CHECKS": True,
    }
}

AUTH_USER_MODEL = "consultorios.Usuario"
PASSWORD_HASHERS = ["django.contrib.auth.hashers.Argon2PasswordHasher"]  # RNF-07
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 10}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

# RNF-16: en base siempre UTC (USE_TZ); cálculos y pantallas en Lima.
LANGUAGE_CODE = "es-pe"
TIME_ZONE = "America/Lima"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "/media/"
# Sitios web completos de cada negocio, ya compilados (scripts/sitio.ps1). RyCitas entra en «Agendar cita».
SITIOS_PROPIOS_DIR = Path(os.environ.get("SITIOS_PROPIOS_DIR", BASE_DIR / "sitios_propios"))
MEDIA_ROOT = Path(os.environ.get("MEDIA_ROOT", BASE_DIR / "media"))
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": "denticita.estaticos_dev.EstaticosDesarrollo"
        if DEBUG
        else "whitenoise.storage.CompressedManifestStaticFilesStorage"
    },
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Detrás de Caddy + Cloudflare.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SESSION_COOKIE_SECURE = not DEBUG
# Panel y admin de la plataforma: la sesión dura 1 h desde el último uso. La app no usa esta sesión (365 días, JWT).
SESSION_COOKIE_AGE = 60 * 60
SESSION_SAVE_EVERY_REQUEST = True
LOGIN_URL = "/panel/entrar/"
CSRF_COOKIE_SECURE = not DEBUG
SECURE_CONTENT_TYPE_NOSNIFF = True
CONFIAR_CLOUDFLARE = _bool("CONFIAR_CLOUDFLARE", not DEBUG)

# django-q2 usa PostgreSQL como cola: sin Redis (regla 1 del MVP). Un solo worker para un VPS pequeño.
Q_CLUSTER = {
    "name": "denticita",
    "orm": "default",
    "workers": 1,
    "recycle": 200,
    "timeout": 120,
    "retry": 180,
    "poll": 2,
    "max_attempts": 3,
    "catch_up": False,
    "save_limit": 200,
    "ack_failures": True,
}

# Sesión del doctor (RNF-07).
TOKEN_ACCESO_MINUTOS = 15
# Se renueva en cada uso: el doctor solo sale al cerrar sesión o si lo desactivan.
TOKEN_RENOVACION_DIAS = 365
LOGIN_MAX_INTENTOS = 5
LOGIN_ESPERA_MINUTOS = 15

# Reserva.
MINUTOS_PRERRESERVA = 15
MAX_CITAS_FUTURAS_POR_NUMERO = 2
MAX_INTENTOS_IP_HORA = int(os.environ.get("MAX_INTENTOS_IP_HORA", "5"))

# Integraciones: vacías en desarrollo; en producción las exige denticita.checks.
# Sitio web: purga de caché, analítica sin cookies y consulta pública de la colegiatura. Todo opcional.
CLOUDFLARE_ZONA = os.environ.get("CLOUDFLARE_ZONA", "")
CLOUDFLARE_TOKEN_CACHE = os.environ.get("CLOUDFLARE_TOKEN_CACHE", "")
CLOUDFLARE_ANALYTICS_TOKEN = os.environ.get("CLOUDFLARE_ANALYTICS_TOKEN", "")
COLEGIATURA_CONSULTA_URL = os.environ.get("COLEGIATURA_CONSULTA_URL", "")
MAX_EVENTOS_IP_HORA = int(os.environ.get("MAX_EVENTOS_IP_HORA", "120"))

TURNSTILE_SITE_KEY = os.environ.get("TURNSTILE_SITE_KEY", "")
TURNSTILE_SECRET = os.environ.get("TURNSTILE_SECRET", "")
# Sin la API de WhatsApp Cloud, la reserva web queda por confirmar y el doctor escribe al paciente desde su
# propio WhatsApp. Con 1 vuelve la verificación por mensaje entrante (webhook de Meta).
VERIFICACION_WHATSAPP = os.environ.get("VERIFICACION_WHATSAPP", "0") == "1"
# Adelantos (Yape, Plin, efectivo) con conciliación manual. Desarrollado pero apagado: con 0 no existe ni en la API
# ni en las pantallas, aunque un negocio lo tenga marcado en sus opciones.
PAGOS_ADELANTADOS = os.environ.get("PAGOS_ADELANTADOS", "0") == "1"
# App del cliente («Quiero reservar»): con 1 (por defecto) exige un código por correo al registrarse y al entrar. Con 0
# basta correo + WhatsApp, dos datos que cualquier negocio conoce (SEG-02): solo para desarrollo. Aparte, las citas,
# sellos y cupones solo se ven tras probar el WhatsApp con el enlace firmado que manda el negocio (SEG-01).
VERIFICAR_CLIENTES = _bool("VERIFICAR_CLIENTES", True)
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "RyCitas <no-responder@rycitas.pe>")
if DEBUG and not os.environ.get("EMAIL_HOST"):
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
EMAIL_HOST = os.environ.get("EMAIL_HOST", "localhost")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", "587"))
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = _bool("EMAIL_USE_TLS", True)
WHATSAPP_NUMERO_PLATAFORMA = os.environ.get("WHATSAPP_NUMERO_PLATAFORMA", "51900000000")
WHATSAPP_APP_SECRET = os.environ.get("WHATSAPP_APP_SECRET", "")
WHATSAPP_VERIFY_TOKEN = os.environ.get("WHATSAPP_VERIFY_TOKEN", "")
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "")
FIREBASE_CREDENCIALES = os.environ.get("FIREBASE_CREDENCIALES", "")

SENTRY_DSN = os.environ.get("SENTRY_DSN", "")
if SENTRY_DSN:
    import sentry_sdk

    # send_default_pii=False: nombres y celulares no salen hacia el servicio de errores (RNF-09).
    sentry_sdk.init(dsn=SENTRY_DSN, send_default_pii=False, traces_sample_rate=0)

# RNF-15: logs estructurados, una línea JSON por evento.
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"json": {"()": "denticita.logs.FormatoJson"}},
    "handlers": {"consola": {"class": "logging.StreamHandler", "formatter": "json"}},
    "root": {"handlers": ["consola"], "level": os.environ.get("LOG_LEVEL", "INFO")},
    "loggers": {"django.db.backends": {"level": "WARNING"}},
}
