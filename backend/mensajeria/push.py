"""Avisos al negocio con Firebase Cloud Messaging (RF-31). Usa la API HTTP v1 sin firebase-admin:
google-auth basta y el contenedor queda mucho más liviano para un VPS pequeño.

Cada aviso pasa primero por la tabla AvisoPendiente (outbox): si Firebase falla o no hay red, se reintenta a los
1, 5, 15 y 60 minutos, y la clave evita mandar dos veces el mismo aviso.
"""
from __future__ import annotations

import logging
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from django_q.tasks import async_task

log = logging.getLogger(__name__)
_sesion = None


def encolar(
    consultorio_id: int,
    titulo: str,
    cuerpo: str,
    datos: dict | None = None,
    *,
    clave: str | None = None,
    profesional_id: int | None = None,
    solo_profesional: bool = False,
) -> bool:
    """Guarda el aviso y lo manda de inmediato en segundo plano. Devuelve False si ya existía (duplicado)."""
    from mensajeria.models import AvisoPendiente

    datos = datos or {}
    try:
        with transaction.atomic():
            aviso = AvisoPendiente.objects.create(
                consultorio_id=consultorio_id,
                profesional_id=profesional_id,
                solo_profesional=solo_profesional and profesional_id is not None,
                clave=clave or f"u:{uuid.uuid4()}",
                titulo=titulo[:120],
                cuerpo=cuerpo[:300],
                datos=datos,
                proximo_intento=timezone.now(),
            )
    except IntegrityError:
        return False
    async_task("mensajeria.push.enviar_a_consultorio", consultorio_id, titulo, cuerpo, datos, aviso.pk)
    return True


def _sesion_fcm():
    global _sesion
    if _sesion is None:
        from google.auth.transport.requests import AuthorizedSession
        from google.oauth2 import service_account

        credenciales = service_account.Credentials.from_service_account_file(
            settings.FIREBASE_CREDENCIALES, scopes=["https://www.googleapis.com/auth/firebase.messaging"]
        )
        _sesion = AuthorizedSession(credenciales)
    return _sesion


# Cada tipo de aviso suena distinto: el canal de Android lleva su propio sonido con voz («Tienes una reserva por
# confirmar»), así el profesional sabe qué pasó sin mirar el teléfono. Deben coincidir con app_doctor/lib/core/push.dart.
# _v2: voz neuronal de Camila (es-PE). Android fija el sonido al crear el canal: un sonido nuevo exige un id nuevo.
CANAL_POR_TIPO = {"por_aprobar": "reservas_v2", "nueva_cita": "nuevas_v2", "cita_proxima": "proximas_v2"}
CANAL_GENERAL = "general_v2"


def canal_de(tipo: str) -> str:
    return CANAL_POR_TIPO.get(tipo, CANAL_GENERAL)


def _dispositivos(consultorio_id: int, profesional_id: int | None, tipo: str = "", solo_profesional: bool = False):
    """A quién le llega el aviso.

    - Con profesional: a sus cuentas y a los encargados (cuentas sin profesional).
    - `solo_profesional`: solo a sus cuentas; si él no tiene ninguna, a los encargados, para que nadie se lo pierda.
    - Nunca a una cuenta que apagó ese tipo de aviso.
    """
    from consultorios.models import Dispositivo

    dispositivos = Dispositivo.objects.filter(usuario__consultorio_id=consultorio_id, usuario__activo=True)
    if tipo:
        dispositivos = dispositivos.exclude(usuario__avisos_apagados__contains=[tipo])
    if profesional_id is None:
        return dispositivos
    propios = dispositivos.filter(usuario__profesional_id=profesional_id)
    encargados = dispositivos.filter(usuario__profesional__isnull=True)
    if solo_profesional:
        tiene_cuenta = Dispositivo.objects.filter(usuario__profesional_id=profesional_id, usuario__activo=True).exists()
        return propios if tiene_cuenta else encargados
    return propios | encargados


def enviar_a_consultorio(
    consultorio_id: int, titulo: str, cuerpo: str, datos: dict, aviso_id: int | None = None
) -> int:
    from mensajeria.models import AvisoPendiente

    aviso = AvisoPendiente.objects.filter(pk=aviso_id).first() if aviso_id else None
    if aviso is not None and aviso.enviado_en is not None:
        return 0  # ya salió en un intento anterior

    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_CREDENCIALES:
        log.info("push omitido (Firebase sin configurar)")
        if aviso is not None:
            aviso.enviado_en, aviso.error = timezone.now(), "Firebase sin configurar"
            aviso.save(update_fields=["enviado_en", "error"])
        return 0

    url = f"https://fcm.googleapis.com/v1/projects/{settings.FIREBASE_PROJECT_ID}/messages:send"
    enviados, fallo = 0, ""
    destinos = _dispositivos(
        consultorio_id,
        aviso.profesional_id if aviso else None,
        str(datos.get("tipo", "")),
        aviso.solo_profesional if aviso else False,
    )
    canal = canal_de(str(datos.get("tipo", "")))
    for dispositivo in destinos:
        mensaje = {
            "message": {
                "token": dispositivo.token_fcm,
                "notification": {"title": titulo, "body": cuerpo},
                "data": {k: str(v) for k, v in datos.items()},
                "android": {"priority": "HIGH", "notification": {"channel_id": canal, "sound": f"aviso_{canal}"}},
            }
        }
        try:
            respuesta = _sesion_fcm().post(url, json=mensaje, timeout=10)
        except Exception as error:  # sin red: se reintenta todo el aviso
            fallo = f"red: {error.__class__.__name__}"
            continue
        if respuesta.status_code in (400, 404) and "UNREGISTERED" in respuesta.text:
            dispositivo.delete()  # app desinstalada o token renovado
        elif respuesta.ok:
            enviados += 1
        else:
            fallo = f"fcm {respuesta.status_code}"
            log.error("fcm respondio %s", respuesta.status_code)
    if aviso is not None:
        _registrar_intento(aviso, enviados, fallo)
    return enviados


def _registrar_intento(aviso, enviados: int, fallo: str) -> None:
    aviso.intentos += 1
    if fallo and not enviados and aviso.intentos <= len(aviso.REINTENTOS_MIN):
        aviso.proximo_intento = timezone.now() + timedelta(minutes=aviso.REINTENTOS_MIN[aviso.intentos - 1])
        aviso.error = fallo[:200]
    else:
        aviso.enviado_en = timezone.now()
        aviso.error = fallo[:200]
    aviso.save(update_fields=["intentos", "proximo_intento", "enviado_en", "error"])


def reintentar_pendientes() -> int:
    """Tarea de cada minuto: los avisos que fallaron y ya les toca otro intento."""
    from mensajeria.models import AvisoPendiente

    pendientes = AvisoPendiente.objects.filter(enviado_en__isnull=True, intentos__gte=1, proximo_intento__lte=timezone.now())
    total = 0
    for aviso in pendientes[:100]:
        enviar_a_consultorio(aviso.consultorio_id, aviso.titulo, aviso.cuerpo, aviso.datos, aviso.pk)
        total += 1
    return total
