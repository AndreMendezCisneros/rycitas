"""Impide desplegar en producción sin los secretos y la configuración de los que depende la seguridad.

Corre con `manage.py check --deploy` (deploy/desplegar.sh lo ejecuta antes de migrar).
"""
from django.conf import settings
from django.core.checks import Error, Tags, register

LARGO_MINIMO_SECRETO = 32


@register(Tags.security, deploy=True)
def secretos_de_produccion(app_configs, **kwargs):
    faltantes = [
        nombre
        for nombre in (
            "SECRET_KEY",
            "JWT_SECRET",
            "TURNSTILE_SECRET",
            "TURNSTILE_SITE_KEY",
            "FIREBASE_PROJECT_ID",
            "FIREBASE_CREDENCIALES",
            *(("WHATSAPP_APP_SECRET", "WHATSAPP_VERIFY_TOKEN") if settings.VERIFICACION_WHATSAPP else ()),
        )
        if not getattr(settings, nombre)
    ]
    errores = [Error(f"Falta configurar {n} en el entorno", id="denticita.E001") for n in faltantes]

    if settings.JWT_SECRET and settings.JWT_SECRET == settings.SECRET_KEY:
        errores.append(
            Error(
                "JWT_SECRET debe ser distinto de DJANGO_SECRET_KEY",
                hint="Genera otra con: openssl rand -base64 48",
                id="denticita.E002",
            )
        )
    if settings.JWT_SECRET and len(settings.JWT_SECRET) < LARGO_MINIMO_SECRETO:
        errores.append(Error(f"JWT_SECRET debe tener al menos {LARGO_MINIMO_SECRETO} caracteres", id="denticita.E003"))
    if settings.PLATAFORMA_DOMINIO in ("", "localhost") or settings.PLATAFORMA_DOMINIO.endswith(".localhost"):
        errores.append(Error("PLATAFORMA_DOMINIO debe ser el dominio real (p. ej. ryjec.com)", id="denticita.E004"))
    if settings.VERIFICAR_CLIENTES and settings.EMAIL_HOST in ("", "localhost"):
        errores.append(
            Error(
                "Con VERIFICAR_CLIENTES=1 los códigos van por correo: configura EMAIL_HOST y sus credenciales",
                id="denticita.E005",
            )
        )
    return errores
