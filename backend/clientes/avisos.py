"""Push a la app del cliente: sus citas (confirmada, cancelada, movida, recordatorios), sellos, tarjeta llena y
campañas del negocio. Mismo Firebase que la app del negocio.

Son avisos de cortesía: si Firebase falla no se reintentan (a diferencia de los del negocio, que van por outbox).
Los de citas solo llegan a quien probó que el WhatsApp es suyo (SEG-01): un número escrito a mano no basta para
enterarse de las citas de otra persona. El texto nunca incluye el servicio ni las notas (DAT-05): se ve en la
pantalla bloqueada y pasa por Google.
"""
from __future__ import annotations

import logging

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django_q.tasks import async_task

log = logging.getLogger(__name__)


def a_cliente(cliente, titulo: str, cuerpo: str, datos: dict) -> None:
    a_celular(cliente.celular, titulo, cuerpo, datos)


def a_celular(celular: str, titulo: str, cuerpo: str, datos: dict) -> None:
    """Se envía al confirmar la transacción: si la acción se deshace, no sale el aviso."""
    transaction.on_commit(lambda: async_task("clientes.avisos.enviar", [celular], titulo, cuerpo, datos))


# Canal de Android de la app del cliente para sus citas (se crea en app_doctor/lib/core/push.dart).
CANAL_CITAS = "mis_citas_v1"


def de_cita(cita, tipo: str) -> None:
    """Aviso al cliente cuando el negocio le reserva, confirma, rechaza, cancela o mueve su cita."""
    from citas.servicios import fecha_legible

    negocio = cita.consultorio.nombre
    cuando = fecha_legible(cita.inicio)
    titulo, cuerpo = {
        "reservada": (f"{negocio} te reservó una cita ✨", f"{cuando[:1].upper()}{cuando[1:]}. Toca para ver los detalles."),
        "confirmada": ("¡Tu cita está confirmada! 🎉", f"{negocio} te espera {cuando}."),
        "rechazada": ("No pudieron confirmar tu reserva", f"{negocio} no tiene ese horario. Toca para elegir otro."),
        "cancelada": ("Tu cita fue cancelada", f"{negocio} canceló tu cita de {cuando}."),
        "movida": ("Tu cita cambió de hora", f"{negocio}: ahora es {cuando}."),
    }[tipo]
    datos = {"tipo": "cita", "cita_id": cita.pk, "negocio": cita.consultorio.slug}
    celular, cuenta = cita.paciente.celular, cita.cliente_id
    transaction.on_commit(
        lambda: async_task("clientes.avisos.enviar", [celular], titulo, cuerpo, datos, None, True, CANAL_CITAS, cuenta)
    )


def recordar_citas() -> int:
    """Cada 5 min: recordatorio un día antes y 2 horas antes, a quien tiene la app. Cada uno sale una vez."""
    from datetime import timedelta

    from django.utils import timezone

    from citas.models import Cita, Estado
    from citas.servicios import fecha_legible

    ahora = timezone.now()
    enviados = 0
    for campo, desde, hasta in (
        ("aviso_cliente_2h_en", ahora, ahora + timedelta(hours=2)),
        ("aviso_cliente_24h_en", ahora + timedelta(hours=2), ahora + timedelta(hours=24)),
    ):
        citas = (
            Cita.objects.filter(
                estado=Estado.PROGRAMADA,
                inicio__gt=desde,
                inicio__lte=hasta,
                consultorio__activo=True,
                **{f"{campo}__isnull": True},
            )
            .select_related("consultorio", "paciente")
            .order_by("inicio")[:500]
        )
        for cita in citas:
            # Se marca primero: si el envío falla, no se repite cada 5 minutos.
            if not Cita.objects.filter(pk=cita.pk, **{f"{campo}__isnull": True}).update(**{campo: ahora}):
                continue
            if campo == "aviso_cliente_2h_en":
                Cita.objects.filter(pk=cita.pk, aviso_cliente_24h_en__isnull=True).update(aviso_cliente_24h_en=ahora)
                titulo = "Tu cita es pronto ⏰"
            else:
                titulo = "Mañana tienes cita ✨" if timezone.localtime(cita.inicio).date() > timezone.localdate() else "Hoy tienes cita ✨"
            cuerpo = f"{cita.consultorio.nombre}, {fecha_legible(cita.inicio)}."
            datos = {"tipo": "recordatorio", "cita_id": cita.pk, "negocio": cita.consultorio.slug}
            async_task(
                "clientes.avisos.enviar",
                [cita.paciente.celular],
                titulo,
                cuerpo,
                datos,
                None,
                True,
                CANAL_CITAS,
                cita.cliente_id,
            )
            enviados += 1
    return enviados


def enviar(
    celulares: list[str],
    titulo: str,
    cuerpo: str,
    datos: dict,
    consultorio_id: int | None = None,
    solo_verificados: bool = False,
    canal: str = "general_v2",
    cuenta_id: int | None = None,
) -> int:
    """Push a los clientes con esos celulares. [cuenta_id]: la cuenta que hizo la reserva desde la app, que recibe
    los avisos de esa cita aunque aún no haya probado su WhatsApp."""
    from clientes.models import DispositivoCliente
    from mensajeria.push import _sesion_fcm

    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_CREDENCIALES:
        log.info("push al cliente omitido (Firebase sin configurar)")
        return 0
    por_numero = Q(cliente__celular__in=celulares)
    if solo_verificados:
        por_numero &= Q(cliente__celular_verificado_en__isnull=False)
    if cuenta_id is not None:
        por_numero |= Q(cliente_id=cuenta_id)
    dispositivos = DispositivoCliente.objects.filter(por_numero, cliente__activo=True)
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
                "android": {
                    "priority": "HIGH",
                    "notification": {"channel_id": canal, "sound": "aviso_general_v2" if canal == "general_v2" else "default"},
                },
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
