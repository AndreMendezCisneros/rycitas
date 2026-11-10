"""Tareas programadas con django-q2 (CU-12)."""
import logging
from datetime import timedelta

from django.db.models import Q
from django.utils import timezone

from agenda.motor import LIMA
from citas import servicios
from citas.models import Cita, ClaveIdempotencia, Estado, IntentoReserva
from consultorios.models import Consultorio, SesionRenovacion
from mensajeria import push
from mensajeria.models import AvisoPendiente, MensajeEntrante
from sitio.models import EventoSitio

log = logging.getLogger(__name__)


def expirar_prerreservas() -> int:
    return servicios.expirar_vencidas()


def resumen_diario() -> int:
    """A las 8 pm: número de citas de mañana y primera hora (RF-32). Sin citas no molesta al doctor."""
    manana = timezone.localdate() + timedelta(days=1)
    enviados = 0
    for consultorio in Consultorio.objects.filter(activo=True):
        citas = Cita.objects.filter(
            consultorio=consultorio,
            estado=Estado.PROGRAMADA,
            inicio__gte=servicios._inicio_de_dia(manana),
            inicio__lt=servicios._inicio_de_dia(manana + timedelta(days=1)),
        ).order_by("inicio")
        primera = citas.first()
        if primera is None:
            continue
        total = citas.count()
        plural = "cita" if total == 1 else "citas"
        hora = servicios.hora_legible(primera.inicio.astimezone(LIMA).time())
        push.encolar(
            consultorio.pk,
            "Agenda de mañana",
            f"{total} {plural}. La primera a las {hora} Toca para enviar los recordatorios.",
            {"tipo": "recordatorios"},
        )
        enviados += 1
    return enviados


def reintentar_avisos() -> int:
    return push.reintentar_pendientes()


def recordar_pendientes() -> int:
    """Mejora 2 del análisis: si una reserva lleva horas sin respuesta, se vuelve a avisar; y otra vez la víspera.

    Un aviso por negocio y por profesional, con clave por hora para no repetirlo en cada vuelta de la tarea.
    """
    ahora = timezone.now()
    manana_fin = servicios._inicio_de_dia(timezone.localdate() + timedelta(days=2))
    enviados = 0
    for consultorio in Consultorio.objects.filter(activo=True, suspendido=False):
        horas = consultorio.opciones_efectivas["recordar_pendientes_horas"]
        if not horas:
            continue
        pendientes = Cita.objects.filter(consultorio=consultorio, estado=Estado.POR_APROBAR, inicio__gt=ahora)
        avisar = pendientes.filter(Q(creado_en__lte=ahora - timedelta(hours=horas)) | Q(inicio__lt=manana_fin))
        grupos: dict[int | None, int] = {}
        for profesional_id in avisar.values_list("profesional_id", flat=True):
            grupos[profesional_id] = grupos.get(profesional_id, 0) + 1
        por_profesional = consultorio.opciones_efectivas["modo_agenda"] == "por_profesional"
        if not por_profesional and grupos:
            grupos = {None: sum(grupos.values())}
        for profesional_id, total in grupos.items():
            texto = "1 reserva espera" if total == 1 else f"{total} reservas esperan"
            if push.encolar(
                consultorio.pk,
                "Tienes reservas por confirmar",
                f"{texto} tu respuesta. El horario sigue apartado hasta que confirmes o rechaces.",
                {"tipo": "por_aprobar"},
                clave=f"pendientes:{consultorio.pk}:{profesional_id}:{timezone.localtime(ahora):%Y%m%d%H}",
                profesional_id=profesional_id,
            ):
                enviados += 1
    return enviados


def recordar_citas_proximas() -> int:
    """Cada 5 min: «En 30 min: tu próxima cita» al profesional de cada cita confirmada que se acerca.

    La clave incluye la hora de la cita: si se mueve, el recordatorio vuelve a salir para la nueva hora.
    """
    ahora = timezone.now()
    enviados = 0
    for consultorio in Consultorio.objects.filter(activo=True, suspendido=False):
        minutos = consultorio.opciones_efectivas["recordar_cita_min"]
        if not minutos:
            continue
        proximas = (
            Cita.objects.filter(
                consultorio=consultorio,
                estado=Estado.PROGRAMADA,
                inicio__gt=ahora,
                inicio__lte=ahora + timedelta(minutes=minutos),
            )
            .select_related("paciente", "profesional")
            .order_by("inicio")
        )
        for cita in proximas:
            faltan = max(1, round((cita.inicio - ahora).total_seconds() / 60))
            hora = cita.inicio.astimezone(LIMA).strftime("%H:%M")
            # Sin nombre ni servicio (DAT-05): se ve en la pantalla bloqueada y pasa por Google.
            if push.encolar(
                consultorio.pk,
                f"En {faltan} min: tu próxima cita",
                f"A las {hora}" + (f" · con {cita.profesional.nombre}" if cita.profesional_id else ""),
                {"tipo": "cita_proxima", "cita_id": str(cita.pk)},
                clave=f"cita_proxima:{cita.pk}:{cita.inicio:%Y%m%d%H%M}",
                profesional_id=cita.profesional_id,
                solo_profesional=True,
            ):
                enviados += 1
    return enviados


def limpieza_diaria() -> None:
    """Datos mínimos (RNF-09): lo operativo no se guarda para siempre."""
    ahora = timezone.now()
    IntentoReserva.objects.filter(creado_en__lt=ahora - timedelta(days=2)).delete()
    SesionRenovacion.objects.filter(expira_en__lt=ahora).delete()
    MensajeEntrante.objects.filter(recibido_en__lt=ahora - timedelta(days=90)).delete()
    EventoSitio.objects.filter(creado_en__lt=ahora - timedelta(days=90)).delete()
    AvisoPendiente.objects.filter(creado_en__lt=ahora - timedelta(days=30)).delete()
    ClaveIdempotencia.objects.filter(creado_en__lt=ahora - timedelta(days=1)).delete()
