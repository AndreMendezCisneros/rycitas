"""Healthcheck del contenedor de tareas: termina con error si la cola está atrasada (deploy/docker-compose.yml)."""
from django.core.management.base import BaseCommand, CommandError

from mensajeria.salud import estado_cola


class Command(BaseCommand):
    help = "Falla si el qcluster dejó de procesar las tareas programadas."

    def handle(self, *args, **opciones):
        estado = estado_cola()
        if estado != "ok":
            raise CommandError(f"cola {estado}")
        self.stdout.write("cola ok")
