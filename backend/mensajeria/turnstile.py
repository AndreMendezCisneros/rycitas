"""Verificación invisible contra robots (RF-17). Si Cloudflare no responde, se rechaza: falla cerrado."""
import logging

import requests
from django.conf import settings

from denticita.errores import ErrorNegocio

log = logging.getLogger(__name__)
URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"


def exigir_token(token: str, ip: str) -> None:
    if settings.DEBUG and not settings.TURNSTILE_SECRET:
        return  # desarrollo local sin Cloudflare
    if not settings.TURNSTILE_SECRET or not token:
        raise ErrorNegocio("verificacion_fallida", "No pudimos verificar tu solicitud. Inténtalo de nuevo.", 403)
    try:
        respuesta = requests.post(
            URL, data={"secret": settings.TURNSTILE_SECRET, "response": token, "remoteip": ip}, timeout=5
        )
        valido = respuesta.json().get("success") is True
    except (requests.RequestException, ValueError):
        log.exception("turnstile no respondio")
        valido = False
    if not valido:
        raise ErrorNegocio("verificacion_fallida", "No pudimos verificar tu solicitud. Inténtalo de nuevo.", 403)
