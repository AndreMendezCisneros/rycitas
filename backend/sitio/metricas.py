"""Métricas del sitio: visitas y pasos vienen de EventoSitio; las citas, de sus estados en la base."""
from datetime import date, datetime, time, timedelta
from statistics import median

from django.conf import settings
from django.db.models import Count, Q

from citas.models import Cita, Estado, Origen
from consultorios.models import Consultorio
from sitio.models import EventoSitio

CONFIRMADAS = (Estado.PROGRAMADA, Estado.EN_CURSO, Estado.TERMINADA, Estado.NO_ASISTIO)


def _tasa(parte: int, total: int) -> float | None:
    return round(100 * parte / total, 1) if total else None


def resumen(consultorio: Consultorio, desde: datetime, hasta: datetime) -> dict:
    eventos = EventoSitio.objects.filter(consultorio=consultorio, creado_en__gte=desde, creado_en__lt=hasta)
    visitas = eventos.filter(tipo=EventoSitio.Tipo.VISITA).count()
    iniciadas = eventos.filter(tipo=EventoSitio.Tipo.PASO_1).count()

    citas = Cita.objects.filter(consultorio=consultorio, origen=Origen.WEB, creado_en__gte=desde, creado_en__lt=hasta)
    creadas = citas.count()
    confirmadas = citas.filter(estado__in=CONFIRMADAS).count()
    expiradas = citas.filter(estado=Estado.EXPIRADA).count()

    # Con verificación, la reserva termina cuando el paciente ve su cita confirmada; sin ella, al enviar sus datos
    # (la confirmación del doctor llega después y no es tiempo del paciente).
    final = EventoSitio.Tipo.CONFIRMADA if settings.VERIFICACION_WHATSAPP else EventoSitio.Tipo.PASO_4
    momentos: dict[str, dict[str, datetime]] = {}
    for sesion, tipo, creado in eventos.filter(tipo__in=[EventoSitio.Tipo.PASO_1, final]).values_list(
        "sesion", "tipo", "creado_en"
    ):
        momentos.setdefault(sesion, {})[tipo] = creado
    duraciones = [(m[final] - m[EventoSitio.Tipo.PASO_1]).total_seconds() for m in momentos.values() if len(m) == 2]
    return {
        "visitas": visitas,
        "reservas_iniciadas": iniciadas,
        "prerreservas": creadas,
        "confirmadas": confirmadas,
        "expiradas": expiradas,
        "conversion_pct": _tasa(confirmadas, visitas),  # meta >= 5 %
        "reserva_completada_pct": _tasa(confirmadas, iniciadas),  # meta >= 60 %
        # Reservas web que terminaron confirmadas: por el paciente (con verificación) o por el doctor (sin ella).
        "confirmacion_pct": _tasa(confirmadas, creadas),  # meta >= 80 %
        "tiempo_mediano_s": round(median(duraciones)) if duraciones else None,  # meta < 60 s
    }


def _mediana_min(segundos: list[float]) -> int | None:
    return round(median(segundos) / 60) if segundos else None


def kpis(consultorio: Consultorio, desde: date, hasta_exclusivo: date) -> dict:
    """Los indicadores del análisis RYJEC (KPI-01 a 08) que se pueden medir sin preguntarle nada a nadie.

    Todas las citas cuentan por su fecha de atención, salvo la confirmación (por la fecha en que se reservó).
    """
    from agenda.models import HorarioSemanal
    from agenda.motor import LIMA
    from citas.models import EventoCita

    inicio = datetime.combine(desde, time.min, LIMA)
    fin = datetime.combine(hasta_exclusivo, time.min, LIMA)
    del_periodo = Cita.objects.filter(consultorio=consultorio, inicio__gte=inicio, inicio__lt=fin)

    web = Cita.objects.filter(consultorio=consultorio, origen=Origen.WEB, creado_en__gte=inicio, creado_en__lt=fin)
    web_cerradas = web.exclude(estado__in=[Estado.POR_APROBAR, Estado.PENDIENTE])
    confirmadas_web = web_cerradas.filter(estado__in=CONFIRMADAS).count()

    # Asistió: la cerró, la está atendiendo o al menos marcó «Llegó» (iniciar y terminar son opcionales).
    atendidas = del_periodo.filter(
        Q(estado__in=[Estado.TERMINADA, Estado.EN_CURSO]) | Q(estado=Estado.PROGRAMADA, llegada_en__isnull=False)
    ).count()
    no_vinieron = del_periodo.filter(estado=Estado.NO_ASISTIO).count()

    # Ocupación: minutos citados frente a minutos de horario (por profesional activo).
    ocupados = 0
    for c in del_periodo.filter(estado__in=[Estado.PROGRAMADA, Estado.EN_CURSO, Estado.TERMINADA]):
        ocupados += (c.fin - c.inicio).total_seconds() / 60
    minutos_semana = {d: 0.0 for d in range(7)}
    for h in HorarioSemanal.objects.filter(consultorio=consultorio, profesional__isnull=True):
        minutos_semana[h.dia_semana] += (
            datetime.combine(desde, h.hora_fin) - datetime.combine(desde, h.hora_inicio)
        ).total_seconds() / 60
    profesionales = max(1, consultorio.profesionales.filter(activo=True).count()
                        if consultorio.opciones_efectivas["modo_agenda"] == "por_profesional" else 1)
    disponibles = 0.0
    dia = desde
    while dia < hasta_exclusivo:
        disponibles += minutos_semana[dia.weekday()] * profesionales
        dia += timedelta(days=1)

    respuestas = [
        (e.fecha - e.cita.creado_en).total_seconds()
        for e in EventoCita.objects.filter(
            cita__consultorio=consultorio, tipo="estado", valor_anterior=Estado.POR_APROBAR,
            valor_nuevo=Estado.PROGRAMADA, fecha__gte=inicio, fecha__lt=fin,
        ).select_related("cita")
    ]
    esperas = [
        (c.inicio_real - c.llegada_en).total_seconds()
        for c in del_periodo.filter(llegada_en__isnull=False, inicio_real__isnull=False)
        if c.inicio_real >= c.llegada_en
    ]
    # Duración real: solo las que usaron «Iniciar» y «Terminar».
    cronometradas = list(
        del_periodo.filter(estado=Estado.TERMINADA, inicio_real__isnull=False, fin_real__isnull=False)
        .values_list("servicio_nombre", "duracion_acordada_min", "inicio_real", "fin_real")
    )
    por_servicio: dict[str, dict] = {}
    for servicio, prevista, ini, fin_r in cronometradas:
        fila = por_servicio.setdefault(servicio or "—", {"servicio": servicio or "—", "previstas": [], "reales": []})
        fila["reales"].append((fin_r - ini).total_seconds())
        if prevista:
            fila["previstas"].append(prevista)
    duracion_por_servicio = sorted(
        (
            {
                "servicio": f["servicio"],
                "citas": len(f["reales"]),
                "real_min": _mediana_min(f["reales"]),
                "prevista_min": round(median(f["previstas"])) if f["previstas"] else None,
            }
            for f in por_servicio.values()
        ),
        key=lambda f: -f["citas"],
    )[:8]
    tardanzas = [
        (ini - prog).total_seconds()
        for prog, ini in del_periodo.filter(inicio_real__isnull=False).values_list("inicio", "inicio_real")
    ]
    demoras = EventoCita.objects.filter(
        cita__consultorio=consultorio, tipo="demora", fecha__gte=inicio, fecha__lt=fin
    ).values("cita_id").distinct().count()
    atendidos = set(del_periodo.filter(estado=Estado.TERMINADA).values_list("paciente_id", flat=True))
    vuelven = (
        Cita.objects.filter(paciente_id__in=atendidos, estado=Estado.TERMINADA)
        .values("paciente_id").annotate(n=Count("id")).filter(n__gte=2).count()
    )
    return {
        "citas": del_periodo.exclude(estado__in=[Estado.PENDIENTE, Estado.EXPIRADA]).count(),
        "confirmacion_pct": _tasa(confirmadas_web, web_cerradas.count()),
        "inasistencia_pct": _tasa(no_vinieron, atendidas + no_vinieron),
        "ocupacion_pct": _tasa(round(ocupados), round(disponibles)) if disponibles else None,
        "respuesta_mediana_min": _mediana_min(respuestas),
        "espera_mediana_min": _mediana_min(esperas),
        "atendidas": atendidas,
        "no_vinieron": no_vinieron,
        "duracion_real_mediana_min": _mediana_min([(f - i).total_seconds() for _, _, i, f in cronometradas]),
        "cronometradas": len(cronometradas),
        "duracion_por_servicio": duracion_por_servicio,
        # Mediana entre la hora de la cita y «Iniciar»: positiva si se empieza tarde.
        "inicio_tarde_mediana_min": round(median(tardanzas) / 60) if tardanzas else None,
        "citas_con_demora": demoras,
        "vuelven_pct": _tasa(vuelven, len(atendidos)),
        "por_confirmar": Cita.objects.filter(consultorio=consultorio, estado=Estado.POR_APROBAR).count(),
    }
