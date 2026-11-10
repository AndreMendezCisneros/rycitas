from datetime import datetime, time, timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone
from django_q.models import Schedule

from agenda.motor import LIMA


def _proxima(hora: time) -> datetime:
    ahora = timezone.localtime()
    candidata = datetime.combine(ahora.date(), hora, LIMA)
    return candidata if candidata > ahora else candidata + timedelta(days=1)


class Command(BaseCommand):
    help = "Crea o actualiza las tareas programadas. Se puede ejecutar en cada despliegue."

    def handle(self, *args, **options):
        tareas = [
            ("expirar-prerreservas", "mensajeria.tareas.expirar_prerreservas", Schedule.MINUTES, 1, timezone.now()),
            ("reintentar-avisos", "mensajeria.tareas.reintentar_avisos", Schedule.MINUTES, 1, timezone.now()),
            ("recordar-pendientes", "mensajeria.tareas.recordar_pendientes", Schedule.MINUTES, 30, timezone.now()),
            ("recordar-citas", "mensajeria.tareas.recordar_citas_proximas", Schedule.MINUTES, 5, timezone.now()),
            ("resumen-diario", "mensajeria.tareas.resumen_diario", Schedule.DAILY, None, _proxima(time(20, 0))),
            ("limpieza-diaria", "mensajeria.tareas.limpieza_diaria", Schedule.DAILY, None, _proxima(time(3, 30))),
        ]
        for nombre, funcion, tipo, minutos, siguiente in tareas:
            existente = Schedule.objects.filter(name=nombre).first()
            valores = {"func": funcion, "schedule_type": tipo, "minutes": minutos, "repeats": -1}
            if existente:
                # Conserva next_run para no disparar el resumen de nuevo en cada despliegue.
                Schedule.objects.filter(pk=existente.pk).update(**valores)
            else:
                Schedule.objects.create(name=nombre, next_run=siguiente, **valores)
        self.stdout.write(self.style.SUCCESS(f"{len(tareas)} tareas programadas"))
