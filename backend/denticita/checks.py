"""Impide desplegar en producción sin los secretos de los que depende la seguridad."""
from django.conf import settings
from django.core.checks import Error, Tags, register


@register(Tags.security, deploy=True)
def secretos_de_produccion(app_configs, **kwargs):
    faltantes = [
        nombre
        for nombre in (
            "SECRET_KEY",
            "JWT_SECRET",
            "TURNSTILE_SECRET",
            "TURNSTILE_SITE_KEY",
            *(("WHATSAPP_APP_SECRET", "WHATSAPP_VERIFY_TOKEN") if settings.VERIFICACION_WHATSAPP else ()),
        )
        if not getattr(settings, nombre)
    ]
    return [Error(f"Falta configurar {n} en el entorno", id="denticita.E001") for n in faltantes]
