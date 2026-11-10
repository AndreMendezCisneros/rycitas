"""Adelantos con conciliación manual (Fase E). Desarrollados y apagados.

Solo funcionan con PAGOS_ADELANTADOS=1 en la plataforma *y* la opción «adelantos» activa en el negocio. No hay
pasarela: el cliente paga por Yape, Plin, efectivo o transferencia y el encargado registra y verifica el pago.
"""
from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from citas import servicios
from citas.models import Adelanto, Cita, Estado
from consultorios.models import Consultorio, Usuario
from denticita.errores import ErrorNegocio

E = Adelanto.EstadoAdelanto


def habilitados(consultorio: Consultorio) -> bool:
    return bool(consultorio.opciones_efectivas["adelantos"])


def exigir_habilitados(consultorio: Consultorio) -> None:
    if not habilitados(consultorio):
        # Como si no existiera: ni la app ni un curioso ven que hay algo detrás.
        raise ErrorNegocio("no_encontrado", "No encontrado.", 404)


def _adelanto(consultorio: Consultorio, adelanto_id: int) -> Adelanto:
    a = (
        Adelanto.objects.select_for_update(of=("self",))
        .select_related("cita")
        .filter(cita__consultorio=consultorio, pk=adelanto_id)
        .first()
    )
    if a is None:
        raise ErrorNegocio("no_encontrado", "No encontramos ese adelanto.", 404)
    return a


def total_recibido(cita: Cita) -> int:
    return sum(a.monto for a in cita.adelantos.all() if a.estado == E.RECIBIDO)


def registrar(
    consultorio: Consultorio,
    usuario: Usuario,
    cita_id: int,
    monto_soles,
    metodo: str,
    operacion: str = "",
    nota: str = "",
) -> Adelanto:
    exigir_habilitados(consultorio)
    monto = servicios.a_centimos(monto_soles)
    if not monto or monto <= 0:
        raise ErrorNegocio("monto_invalido", "El adelanto debe ser mayor a cero.", 422)
    if metodo not in Adelanto.Metodo.values:
        raise ErrorNegocio("metodo_invalido", "Elige Yape, Plin, efectivo o transferencia.", 422)
    with transaction.atomic():
        cita = servicios._bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado not in (Estado.POR_APROBAR, Estado.PROGRAMADA, Estado.EN_CURSO):
            raise ErrorNegocio("transicion_invalida", "Esta cita ya no admite adelantos.", 409)
        tope = cita.precio_vigente
        ya_pagado = sum(a.monto for a in cita.adelantos.exclude(estado=E.DEVUELTO))
        if tope and ya_pagado + monto > tope:
            raise ErrorNegocio("monto_excede", f"El adelanto supera el precio ({servicios.soles(tope)}).", 422)
        adelanto = Adelanto.objects.create(
            cita=cita,
            monto=monto,
            metodo=metodo,
            operacion=operacion.strip()[:40],
            nota=nota.strip()[:200],
            registrado_por=usuario,
        )
        servicios._evento(cita, "adelanto", "", f"{servicios.soles(monto)} {metodo}"[:60], usuario)
    return adelanto


def conciliar(consultorio: Consultorio, usuario: Usuario, adelanto_id: int) -> Adelanto:
    """El encargado vio el pago en su Yape o en su banco."""
    exigir_habilitados(consultorio)
    with transaction.atomic():
        a = _adelanto(consultorio, adelanto_id)
        if a.estado != E.PENDIENTE:
            raise ErrorNegocio("transicion_invalida", "Ese adelanto ya fue verificado.", 409, estado=a.estado)
        a.estado, a.conciliado_en = E.RECIBIDO, timezone.now()
        a.save(update_fields=["estado", "conciliado_en"])
        servicios._evento(a.cita, "adelanto", E.PENDIENTE, E.RECIBIDO, usuario)
    return a


def devolver(consultorio: Consultorio, usuario: Usuario, adelanto_id: int, nota: str = "") -> Adelanto:
    exigir_habilitados(consultorio)
    with transaction.atomic():
        a = _adelanto(consultorio, adelanto_id)
        if a.estado == E.DEVUELTO:
            raise ErrorNegocio("transicion_invalida", "Ese adelanto ya se devolvió.", 409, estado=a.estado)
        anterior = a.estado
        a.estado, a.devuelto_en = E.DEVUELTO, timezone.now()
        if nota:
            a.nota = nota.strip()[:200]
        a.save(update_fields=["estado", "devuelto_en", "nota"])
        servicios._evento(a.cita, "adelanto", anterior, E.DEVUELTO, usuario)
    return a


def adelanto_publico(a: Adelanto) -> dict:
    return {
        "id": a.pk,
        "monto": servicios.soles(a.monto),
        "monto_centimos": a.monto,
        "metodo": a.metodo,
        "estado": a.estado,
        "operacion": a.operacion,
        "nota": a.nota,
        "creado_en": a.creado_en.isoformat(),
        "conciliado_en": a.conciliado_en.isoformat() if a.conciliado_en else None,
        "devuelto_en": a.devuelto_en.isoformat() if a.devuelto_en else None,
    }
