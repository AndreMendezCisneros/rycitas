"""Webhook de WhatsApp Cloud API (RF-10). Solo recibe: el sistema nunca responde, así no paga mensajes."""
import hashlib
import hmac
import json
import logging

from django.conf import settings
from django.db import transaction
from django.http import Http404, HttpResponse, HttpResponseForbidden
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from citas import servicios
from mensajeria.models import MensajeEntrante

log = logging.getLogger(__name__)


def firma_valida(cuerpo: bytes, firma: str) -> bool:
    if not settings.WHATSAPP_APP_SECRET:  # sin secreto configurado no se acepta nada, ni en desarrollo
        return False
    esperada = "sha256=" + hmac.new(settings.WHATSAPP_APP_SECRET.encode(), cuerpo, hashlib.sha256).hexdigest()
    return hmac.compare_digest(esperada, firma or "")


def _mensajes(cuerpo: dict):
    for entrada in cuerpo.get("entry", []):
        for cambio in entrada.get("changes", []):
            yield from cambio.get("value", {}).get("messages", []) or []


def procesar_mensaje(mensaje: dict) -> None:
    wamid = mensaje.get("id")
    celular = mensaje.get("from", "")
    if not wamid or not celular:
        return
    texto = (mensaje.get("text") or {}).get("body", "") if mensaje.get("type") == "text" else ""
    with transaction.atomic():
        registro, creado = MensajeEntrante.objects.get_or_create(
            wamid=wamid, defaults={"celular": celular[:20], "texto": texto}
        )
        if not creado:  # Meta reintenta entregas: procesar solo una vez
            return
        cita = servicios.confirmar_por_whatsapp(f"+{celular.lstrip('+')}", texto)
        if cita is not None:
            registro.cita = cita
            registro.save(update_fields=["cita"])


@csrf_exempt
@require_http_methods(["GET", "POST"])
def webhook_whatsapp(request):
    if not settings.VERIFICACION_WHATSAPP:
        raise Http404()
    if request.method == "GET":
        if (
            settings.WHATSAPP_VERIFY_TOKEN
            and request.GET.get("hub.mode") == "subscribe"
            and hmac.compare_digest(request.GET.get("hub.verify_token", ""), settings.WHATSAPP_VERIFY_TOKEN)
        ):
            return HttpResponse(request.GET.get("hub.challenge", ""), content_type="text/plain")
        return HttpResponseForbidden()

    if not firma_valida(request.body, request.headers.get("X-Hub-Signature-256", "")):
        log.warning("webhook con firma invalida")
        return HttpResponseForbidden()
    try:
        cuerpo = json.loads(request.body)
    except ValueError:
        return HttpResponse(status=400)

    for mensaje in _mensajes(cuerpo):
        procesar_mensaje(mensaje)
    return HttpResponse(status=200)
