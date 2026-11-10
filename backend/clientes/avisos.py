"""Push a la app del cliente (sellos, tarjeta llena, campañas del negocio). Mismo Firebase que la app del negocio.

Son avisos de cortesía: si Firebase falla no se reintentan (a diferencia de los del negocio, que van por outbox).
"""
from __future__ import annotations

import logging

from django.conf import settings
from django.db import transaction
from django_q.tasks import async_task

log = logging.getLogger(__name__)


def a_cliente(cliente, titulo: str, cuerpo: str, datos: dict) -> None:
    a_celular(cliente.celular, titulo, cuerpo, datos)


def a_celular(celular: str, titulo: str, cuerpo: str, datos: dict) -> None:
    """Se envía al confirmar la transacción: si la acción se deshace, no sale el aviso."""
    transaction.on_commit(lambda: async_task("clientes.avisos.enviar", [celular], titulo, cuerpo, datos))


def enviar(celulares: list[str], titulo: str, cuerpo: str, datos: dict, consultorio_id: int | None = None) -> int:
    from clientes.models import DispositivoCliente
    from mensajeria.push import _sesion_fcm

    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_CREDENCIALES:
        log.info("push al cliente omitido (Firebase sin configurar): %s", titulo)
        return 0
    dispositivos = DispositivoCliente.objects.filter(cliente__celular__in=celulares, cliente__activo=True)
    if consultorio_id is not None:  # quien silenció al negocio no recibe sus campañas
        dispositivos = dispositivos.exclude(cliente__silenciados__id=consultorio_id)
    url = f"https://fcm.googleapis.com/v1/projects/{settings.FIREBASE_PROJECT_ID}/messages:send"
    enviados = 0
    for dispositivo in dispositivos:
        mensaje = {
            "message": {
                "token": dispositivo.token_fcm,
                "notification": {"title": titulo, "body": cuerpo},
                "data": {k: str(v) for k, v in datos.items()},
                "android": {"priority": "HIGH", "notification": {"channel_id": "general_v2", "sound": "aviso_general_v2"}},
            }
        }
        try:
            respuesta = _sesion_fcm().post(url, json=mensaje, timeout=10)
        except Exception as error:
            log.warning("push al cliente sin red: %s", error.__class__.__name__)
            continue
        if respuesta.status_code in (400, 404) and "UNREGISTERED" in respuesta.text:
            dispositivo.delete()
        elif respuesta.ok:
            enviados += 1
    return enviados
