"""Sellos, niveles, referidos y segmentos de clientes de un negocio.

Reglas pensadas para que no se pueda abusar:
- El sello se gana con la visita **terminada**, no al reservar.
- El sello de puntualidad exige que el negocio haya marcado «Llegó» antes de la hora (más 5 min de gracia).
- El referido da sello a ambos recién cuando el amigo termina su primera cita en cualquier negocio.
"""
from __future__ import annotations

import logging
from datetime import timedelta

from django.db import IntegrityError, transaction
from django.db.models import Count, Max, Q
from django.utils import timezone

from citas.models import Cita, Estado, Paciente
from clientes.models import Canje, Cliente, Cupon, CuponUsado, Sello, Segmento
from consultorios.models import Consultorio
from denticita.errores import ErrorNegocio

log = logging.getLogger(__name__)

GRACIA_PUNTUAL_MIN = 5
NIVELES = (("oro", "Oro", 6), ("plata", "Plata", 3), ("bronce", "Bronce", 0))  # visitas en 6 meses
VENTANA_NIVEL_DIAS = 180
INACTIVO_DIAS = 60
CAIDAS = [Estado.CANCELADA, Estado.EXPIRADA]  # un cupón de una reserva que no se dio vuelve a estar libre


def nivel_por_visitas(visitas: int) -> dict:
    for clave, nombre, minimo in NIVELES:
        if visitas >= minimo:
            siguiente = next((n for n in reversed(NIVELES) if n[2] > minimo), None)
            return {
                "clave": clave,
                "nombre": nombre,
                "visitas": visitas,
                "siguiente": siguiente[1] if siguiente else None,
                "faltan": siguiente[2] - visitas if siguiente else 0,
            }
    raise AssertionError


def visitas_recientes(consultorio_id: int, celular: str) -> int:
    desde = timezone.now() - timedelta(days=VENTANA_NIVEL_DIAS)
    return Cita.objects.filter(
        consultorio_id=consultorio_id, paciente__celular=celular, estado=Estado.TERMINADA, inicio__gte=desde
    ).count()


def tarjeta(consultorio: Consultorio, celular: str) -> dict:
    o = consultorio.opciones_efectivas
    sellos = Sello.objects.filter(consultorio=consultorio, celular=celular, canje__isnull=True)
    total = sellos.count()
    meta = max(1, int(o["fidelidad_meta"]))
    return {
        "activa": bool(o["fidelidad_activa"]),
        "sellos": min(total, meta),
        "meta": meta,
        "premio": o["fidelidad_premio"],
        "lista": total >= meta,
        "puntualidad": bool(o["sello_puntualidad"]),
        "historial": [
            {"motivo": s.motivo, "texto": s.get_motivo_display(), "fecha": s.creado_en.date().isoformat()}
            for s in sellos.order_by("-creado_en")[:meta]
        ],
        "nivel": nivel_por_visitas(visitas_recientes(consultorio.pk, celular)),
    }


def _dar(consultorio_id: int, celular: str, motivo: str, cita: Cita | None) -> bool:
    try:
        with transaction.atomic():
            Sello.objects.create(consultorio_id=consultorio_id, celular=celular, motivo=motivo, cita=cita)
    except IntegrityError:
        return False  # esa cita ya dio ese sello
    return True


def al_terminar(cita: Cita) -> list[str]:
    """Se llama cuando el negocio marca «Terminar». Devuelve los motivos de los sellos que dio."""
    o = cita.consultorio.opciones_efectivas
    if not o["fidelidad_activa"]:
        return []
    celular = cita.paciente.celular
    antes = Sello.objects.filter(consultorio_id=cita.consultorio_id, celular=celular, canje__isnull=True).count()
    dados = []
    if _dar(cita.consultorio_id, celular, Sello.Motivo.VISITA, cita):
        dados.append(Sello.Motivo.VISITA)
    limite = cita.inicio + timedelta(minutes=GRACIA_PUNTUAL_MIN)
    if o["sello_puntualidad"] and cita.llegada_en and cita.llegada_en <= limite:
        if _dar(cita.consultorio_id, celular, Sello.Motivo.PUNTUAL, cita):
            dados.append(Sello.Motivo.PUNTUAL)
    dados += _premiar_referido(cita)

    if dados:
        from clientes import avisos

        meta = max(1, int(o["fidelidad_meta"]))
        total = antes + len(dados)
        if antes < meta <= total:
            avisos.a_celular(
                celular,
                f"¡Tarjeta llena en {cita.consultorio.nombre}!",
                f"Ganaste: {o['fidelidad_premio']}. Muéstralo en tu próxima visita.",
                {"tipo": "tarjeta_llena", "negocio": cita.consultorio.slug},
            )
        else:
            avisos.a_celular(
                celular,
                f"+{len(dados)} sello{'s' if len(dados) > 1 else ''} en {cita.consultorio.nombre}",
                f"Llevas {min(total, meta)} de {meta}. Premio: {o['fidelidad_premio']}.",
                {"tipo": "sello", "negocio": cita.consultorio.slug},
            )
    return dados


def _premiar_referido(cita: Cita) -> list[str]:
    """Primera cita terminada del amigo: un sello para él y otro para quien lo invitó, en este negocio."""
    amigo = (
        Cliente.objects.select_related("referido_por")
        .filter(celular=cita.paciente.celular, referido_por__isnull=False, referido_premiado_en__isnull=True)
        .first()
    )
    if amigo is None:
        return []
    otras = Cita.objects.filter(paciente__celular=amigo.celular, estado=Estado.TERMINADA).exclude(pk=cita.pk)
    if otras.exists():
        return []
    amigo.referido_premiado_en = timezone.now()
    amigo.save(update_fields=["referido_premiado_en"])
    dados = []
    if _dar(cita.consultorio_id, amigo.celular, Sello.Motivo.REFERIDO, cita):
        dados.append(Sello.Motivo.REFERIDO)
    padrino = amigo.referido_por
    if padrino.celular != amigo.celular:
        Sello.objects.create(consultorio_id=cita.consultorio_id, celular=padrino.celular, motivo=Sello.Motivo.REFERIDO)
        from clientes import avisos

        avisos.a_cliente(
            padrino,
            f"{amigo.nombre.split()[0]} vino gracias a ti",
            f"Ganaste un sello en {cita.consultorio.nombre}.",
            {"tipo": "sello", "negocio": cita.consultorio.slug},
        )
    return dados


def canjear(consultorio: Consultorio, celular: str) -> Canje:
    """El negocio entrega el premio: se usan los sellos de la tarjeta y empieza una nueva."""
    o = consultorio.opciones_efectivas
    meta = max(1, int(o["fidelidad_meta"]))
    with transaction.atomic():
        sellos = list(
            Sello.objects.select_for_update()
            .filter(consultorio=consultorio, celular=celular, canje__isnull=True)
            .order_by("creado_en")[:meta]
        )
        if len(sellos) < meta:
            raise ErrorNegocio("tarjeta_incompleta", f"Faltan {meta - len(sellos)} sellos para el premio.", 409)
        canje = Canje.objects.create(consultorio=consultorio, celular=celular, premio=o["fidelidad_premio"])
        Sello.objects.filter(pk__in=[s.pk for s in sellos]).update(canje=canje)
    return canje


# --- Segmentos para cupones y campañas ---------------------------------------------------------------


def clientes_del_negocio(consultorio: Consultorio):
    """Pacientes reales (con al menos una visita terminada), con sus visitas y la última."""
    return (
        Paciente.objects.filter(consultorio=consultorio, bloqueado=False)
        .annotate(
            visitas=Count("citas", filter=Q(citas__estado=Estado.TERMINADA)),
            recientes=Count(
                "citas",
                filter=Q(
                    citas__estado=Estado.TERMINADA,
                    citas__inicio__gte=timezone.now() - timedelta(days=VENTANA_NIVEL_DIAS),
                ),
            ),
            ultima=Max("citas__inicio", filter=Q(citas__estado=Estado.TERMINADA)),
        )
        .filter(visitas__gt=0)
    )


def del_segmento(consultorio: Consultorio, segmento: str):
    consulta = clientes_del_negocio(consultorio)
    if segmento == Segmento.INACTIVOS:
        return consulta.filter(ultima__lt=timezone.now() - timedelta(days=INACTIVO_DIAS))
    if segmento == Segmento.ORO:
        return consulta.filter(recientes__gte=NIVELES[0][2])
    if segmento == Segmento.NUEVOS:
        return consulta.filter(visitas=1)
    return consulta


def en_segmento(consultorio: Consultorio, segmento: str, celular: str) -> bool:
    return del_segmento(consultorio, segmento).filter(celular=celular).exists()


# --- Cupones ---------------------------------------------------------------------------------------------


def usos(cupon: Cupon) -> int:
    return CuponUsado.objects.filter(cupon=cupon).exclude(
        cita__estado__in=CAIDAS
    ).count()


def cupon_vigente(cupon: Cupon) -> bool:
    if not cupon.activo or cupon.vence_el < timezone.localdate():
        return False
    return cupon.usos_max is None or usos(cupon) < cupon.usos_max


def cupones_para(consultorio: Consultorio, celular: str) -> list[Cupon]:
    usados = set(
        CuponUsado.objects.filter(celular=celular, cupon__consultorio=consultorio)
        .exclude(cita__estado__in=CAIDAS)
        .values_list("cupon_id", flat=True)
    )
    return [
        c
        for c in Cupon.objects.filter(consultorio=consultorio, activo=True, vence_el__gte=timezone.localdate())
        if c.pk not in usados and cupon_vigente(c) and en_segmento(consultorio, c.segmento, celular)
    ]


def descuento_texto(cupon: Cupon) -> str:
    if cupon.descuento_pct:
        return f"{cupon.descuento_pct} %"
    if cupon.descuento_monto:
        from citas.servicios import soles

        return soles(cupon.descuento_monto)
    return ""


def cupon_publico(cupon: Cupon) -> dict:
    return {
        "id": cupon.pk,
        "codigo": cupon.codigo,
        "titulo": cupon.titulo,
        "descuento": descuento_texto(cupon),
        "servicio": cupon.tratamiento.nombre if cupon.tratamiento_id else None,
        "servicio_slug": cupon.tratamiento.slug if cupon.tratamiento_id else None,
        "vence_el": cupon.vence_el.isoformat(),
    }
