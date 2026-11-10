"""¿Sigue viva la cola de tareas? (PRD-04)

django-q adelanta `next_run` de cada tarea programada cada vez que la encola. Si la de cada minuto quedó varios
minutos en el pasado, el qcluster está caído o colgado: no expiran las pre-reservas ni salen los recordatorios.
"""
from datetime import timedelta

from django.utils import timezone
from django_q.models import Schedule

TAREA_TESTIGO = "expirar-prerreservas"  # corre cada minuto
TOLERANCIA = timedelta(minutes=5)


def estado_cola() -> str:
    """«ok», «atrasada» o «sin_programar» (falta correr programar_tareas)."""
    tarea = Schedule.objects.filter(name=TAREA_TESTIGO).only("next_run").first()
    if tarea is None or tarea.next_run is None:
        return "sin_programar"
    return "atrasada" if tarea.next_run < timezone.now() - TOLERANCIA else "ok"
