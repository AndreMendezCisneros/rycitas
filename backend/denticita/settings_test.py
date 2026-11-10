from .settings import *  # noqa: F403

DEBUG = False
ALLOWED_HOSTS = ["*"]
STORAGES["staticfiles"] = {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"}  # noqa: F405
Q_CLUSTER = {**Q_CLUSTER, "sync": True}  # noqa: F405
PLATAFORMA_DOMINIO = "denticita.test"
TURNSTILE_SECRET = ""
WHATSAPP_APP_SECRET = "secreto-de-prueba"
WHATSAPP_VERIFY_TOKEN = "token-de-prueba"
WHATSAPP_NUMERO_PLATAFORMA = "51900000000"
FIREBASE_PROJECT_ID = ""
SECRET_KEY = "clave-de-pruebas-suficientemente-larga-para-firmar-jwt-hs256"
JWT_SECRET = SECRET_KEY
CONFIAR_CLOUDFLARE = True
# Fijas aquí para que las pruebas no dependan del entorno de quien las corre (scripts/dev.ps1 cambia varias).
VERIFICAR_CLIENTES = False
MAX_INTENTOS_IP_HORA = 5
MAX_EVENTOS_IP_HORA = 120
CLOUDFLARE_ZONA = CLOUDFLARE_TOKEN_CACHE = CLOUDFLARE_ANALYTICS_TOKEN = ""
MIDDLEWARE = [m for m in MIDDLEWARE if "cors_dev" not in m]  # noqa: F405
LOGGING = {"version": 1, "disable_existing_loggers": False}
