"""Configuración del consultorio desde la app: horario, bloqueos y tratamientos (RF-25 a RF-27)."""
from statistics import median
from datetime import datetime, time
from decimal import Decimal

from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema

from agenda.models import Bloqueo, HorarioSemanal, Tratamiento
from sitio.cache import purgar_sitio
from citas.models import ESTADOS_ACTIVOS, Cita, Estado
from agenda.motor import LIMA
from citas import servicios
from citas.presentacion import base_url_consultorio, cita_doctor, iso
from consultorios.permisos import solo_general
from denticita.errores import ErrorNegocio

router = Router(tags=["configuración"])


class TramoEntrada(Schema):
    dia_semana: int
    hora_inicio: time
    hora_fin: time


class HorarioEntrada(Schema):
    tramos: list[TramoEntrada]


class BloqueoEntrada(Schema):
    inicio: datetime
    fin: datetime
    motivo: str = ""


class TratamientoEntrada(Schema):
    nombre: str
    motivo_paciente: str = ""
    descripcion: str = ""
    indicaciones: str = ""
    duracion_min: int
    margen_min: int = 0
    precio_desde: Decimal | None = None
    reservable: bool = True
    visible: bool = True
    orden: int = 0


def _horario(consultorio) -> dict:
    return {
        "tramos": [
            {"id": h.pk, "dia_semana": h.dia_semana, "hora_inicio": f"{h.hora_inicio:%H:%M}", "hora_fin": f"{h.hora_fin:%H:%M}"}
            for h in HorarioSemanal.objects.filter(consultorio=consultorio, profesional__isnull=True)
        ]
    }


@router.get("/horario")
def ver_horario(request):
    return _horario(request.auth.consultorio)


def _validar_tramos(datos: HorarioEntrada) -> None:
    for t in datos.tramos:
        if not 0 <= t.dia_semana <= 6:
            raise ErrorNegocio("dia_invalido", "Día de la semana no válido.", 422)
        if t.hora_inicio >= t.hora_fin:
            raise ErrorNegocio("tramo_invalido", "La hora de inicio debe ser antes de la hora de fin.", 422)


def _dentro_del_horario(cita: Cita, tramos: list[TramoEntrada]) -> bool:
    inicio, fin = cita.inicio.astimezone(LIMA), cita.fin.astimezone(LIMA)
    if inicio.date() != fin.date():
        return False
    return any(
        t.dia_semana == inicio.weekday() and t.hora_inicio <= inicio.time() and fin.time() <= t.hora_fin for t in tramos
    )


@router.post("/horario/impacto")
def impacto_horario(request, datos: HorarioEntrada):
    """Mejora 11: antes de guardar un horario nuevo, las citas futuras que quedarían fuera, con su aviso listo.

    Nada se cancela solo: el encargado decide si mueve cada cita o la atiende igual.
    """
    solo_general(request, "Solo la cuenta general del negocio puede cambiar el horario.")
    _validar_tramos(datos)
    consultorio = request.auth.consultorio
    con_horario_propio = HorarioSemanal.objects.filter(consultorio=consultorio, profesional__isnull=False).values(
        "profesional_id"
    )
    citas = (
        Cita.objects.filter(
            consultorio=consultorio, estado__in=[Estado.POR_APROBAR, Estado.PROGRAMADA], inicio__gte=timezone.now()
        )
        .exclude(profesional_id__in=con_horario_propio)
        .select_related("paciente", "tratamiento", "consultorio", "profesional")
        .order_by("inicio")
    )
    base = base_url_consultorio(consultorio, request)
    fuera = [c for c in citas if not _dentro_del_horario(c, datos.tramos)]
    return {
        "citas": [
            {**cita_doctor(c), "whatsapp_url": servicios.aviso_al_paciente(c, base, "horario")} for c in fuera
        ]
    }


@router.put("/horario")
def guardar_horario(request, datos: HorarioEntrada):
    """Reemplaza el horario del negocio. La reserva web lo ve al instante: la disponibilidad no se cachea.

    Los horarios propios de cada profesional se editan en el panel y aquí no se tocan.
    """
    solo_general(request, "Solo la cuenta general del negocio puede cambiar el horario.")
    consultorio = request.auth.consultorio
    _validar_tramos(datos)
    with transaction.atomic():
        HorarioSemanal.objects.filter(consultorio=consultorio, profesional__isnull=True).delete()
        purgar_sitio(consultorio.slug)
        HorarioSemanal.objects.bulk_create(
            HorarioSemanal(
                consultorio=consultorio, dia_semana=t.dia_semana, hora_inicio=t.hora_inicio, hora_fin=t.hora_fin
            )
            for t in datos.tramos
        )
    return _horario(consultorio)


def _bloqueo(b: Bloqueo) -> dict:
    return {"id": b.pk, "inicio": iso(b.inicio), "fin": iso(b.fin), "motivo": b.motivo}


def _citas_afectadas(request, inicio: datetime, fin: datetime):
    """La cuenta de un profesional solo bloquea su agenda: solo ve sus propias citas afectadas."""
    citas = (
        Cita.objects.filter(
            consultorio=request.auth.consultorio, estado__in=ESTADOS_ACTIVOS, inicio__lt=fin, fin_ocupado__gt=inicio
        )
        .exclude(estado=Estado.PENDIENTE)
        .select_related("paciente", "tratamiento")
    )
    if request.auth.profesional_id:
        citas = citas.filter(profesional_id=request.auth.profesional_id)
    return citas


MAX_DIAS_BLOQUEO = 366


def _validar_rango(inicio: datetime, fin: datetime) -> None:
    if inicio.tzinfo is None or fin.tzinfo is None:
        raise ErrorNegocio("hora_invalida", "La hora debe incluir zona horaria.", 422)
    if inicio >= fin:
        raise ErrorNegocio("rango_invalido", "El bloqueo debe terminar después de empezar.", 422)
    if (fin - inicio).days > MAX_DIAS_BLOQUEO:
        raise ErrorNegocio("rango_invalido", "Un bloqueo puede durar como máximo un año.", 422)


def _bloqueos_de(request):
    """La cuenta general maneja todos; la de un profesional, solo los suyos (y ve los del negocio entero)."""
    bloqueos = Bloqueo.objects.filter(consultorio=request.auth.consultorio)
    if request.auth.profesional_id:
        bloqueos = bloqueos.filter(Q(profesional__isnull=True) | Q(profesional_id=request.auth.profesional_id))
    return bloqueos


@router.get("/bloqueos")
def listar_bloqueos(request):
    return {"bloqueos": [_bloqueo(b) for b in _bloqueos_de(request)]}


@router.get("/bloqueos/impacto")
def impacto_bloqueo(request, inicio: datetime, fin: datetime):
    """Citas que quedarían dentro del bloqueo: la app las lista antes de confirmar (RF-26)."""
    _validar_rango(inicio, fin)
    return {"citas": [cita_doctor(c) for c in _citas_afectadas(request, inicio, fin)]}


@router.post("/bloqueos", response={201: dict})
def crear_bloqueo(request, datos: BloqueoEntrada):
    """La cuenta general cierra todo el negocio; la de un profesional, solo su propia agenda (SEG-03)."""
    _validar_rango(datos.inicio, datos.fin)
    bloqueo = Bloqueo.objects.create(
        consultorio=request.auth.consultorio,
        profesional_id=request.auth.profesional_id,
        inicio=datos.inicio,
        fin=datos.fin,
        motivo=datos.motivo[:120],
    )
    return 201, _bloqueo(bloqueo)


@router.delete("/bloqueos/{bloqueo_id}", response={204: None})
def borrar_bloqueo(request, bloqueo_id: int):
    """Un profesional no borra el cierre del negocio entero: solo sus propios bloqueos."""
    bloqueos = Bloqueo.objects.filter(consultorio=request.auth.consultorio)
    if request.auth.profesional_id:
        bloqueos = bloqueos.filter(profesional_id=request.auth.profesional_id)
    get_object_or_404(bloqueos, pk=bloqueo_id).delete()
    return 204, None


def _tratamiento(t: Tratamiento) -> dict:
    return {
        "id": t.pk,
        "nombre": t.nombre,
        "slug": t.slug,
        "motivo_paciente": t.motivo_paciente,
        "descripcion": t.descripcion,
        "indicaciones": t.indicaciones,
        "duracion_min": t.duracion_min,
        "margen_min": t.margen_min,
        "precio_desde": str(t.precio_desde) if t.precio_desde is not None else None,
        "reservable": t.reservable,
        "visible": t.visible,
        "orden": t.orden,
    }


def _validar_tratamiento(datos: TratamientoEntrada) -> None:
    if not datos.nombre.strip():
        raise ErrorNegocio("nombre_invalido", "Escribe el nombre del tratamiento.", 422)
    if not 5 <= datos.duracion_min <= 480:
        raise ErrorNegocio("duracion_invalida", "La duración debe estar entre 5 y 480 minutos.", 422)
    if not 0 <= datos.margen_min <= 120:
        raise ErrorNegocio("margen_invalido", "El margen debe estar entre 0 y 120 minutos.", 422)


def _duraciones_reales(consultorio, muestra: int = 20) -> dict[int, tuple[int, int]]:
    """Mediana de lo que de verdad duraron las últimas citas terminadas de cada tratamiento (Iniciar → Terminar)."""
    por_tratamiento: dict[int, list[float]] = {}
    terminadas = (
        Cita.objects.filter(consultorio=consultorio, estado=Estado.TERMINADA, inicio_real__isnull=False, fin_real__isnull=False)
        .order_by("-fin_real")
        .values_list("tratamiento_id", "inicio_real", "fin_real")
    )
    for tratamiento_id, inicio, fin in terminadas[:2000]:
        lista = por_tratamiento.setdefault(tratamiento_id, [])
        if len(lista) < muestra:
            lista.append((fin - inicio).total_seconds() / 60)
    return {t: (round(median(m)), len(m)) for t, m in por_tratamiento.items()}


@router.get("/tratamientos")
def listar_tratamientos(request):
    consultorio = request.auth.consultorio
    reales = _duraciones_reales(consultorio)
    return {
        "tratamientos": [
            {**_tratamiento(t), "duracion_real_min": reales.get(t.pk, (None, 0))[0], "duracion_real_citas": reales.get(t.pk, (None, 0))[1]}
            for t in Tratamiento.objects.filter(consultorio=consultorio)
        ]
    }


@router.post("/tratamientos", response={201: dict})
def crear_tratamiento(request, datos: TratamientoEntrada):
    solo_general(request, "Solo la cuenta general del negocio puede cambiar los servicios.")
    _validar_tratamiento(datos)
    t = Tratamiento.objects.create(consultorio=request.auth.consultorio, **datos.dict())
    return 201, _tratamiento(t)


@router.put("/tratamientos/{tratamiento_id}")
def editar_tratamiento(request, tratamiento_id: int, datos: TratamientoEntrada):
    solo_general(request, "Solo la cuenta general del negocio puede cambiar los servicios.")
    _validar_tratamiento(datos)
    t = get_object_or_404(Tratamiento, consultorio=request.auth.consultorio, pk=tratamiento_id)
    for campo, valor in datos.dict().items():
        setattr(t, campo, valor)
    t.save()
    return _tratamiento(t)


@router.delete("/tratamientos/{tratamiento_id}", response={204: None})
def borrar_tratamiento(request, tratamiento_id: int):
    """Con citas registradas solo se oculta: el historial debe seguir mostrando el tratamiento."""
    solo_general(request, "Solo la cuenta general del negocio puede cambiar los servicios.")
    t = get_object_or_404(Tratamiento, consultorio=request.auth.consultorio, pk=tratamiento_id)
    if t.citas.exists():
        t.reservable = False
        t.visible = False
        t.save(update_fields=["reservable", "visible"])
    else:
        t.delete()
    return 204, None
