from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from consultorios.models import Consultorio
from sitio.metricas import resumen


class Command(BaseCommand):
    help = "Métricas del sitio de un consultorio: visitas, embudo de reserva y tiempo mediano."

    def add_arguments(self, parser):
        parser.add_argument("slug")
        parser.add_argument("--dias", type=int, default=30)

    def handle(self, *args, slug, dias, **options):
        consultorio = Consultorio.objects.filter(slug=slug).first()
        if consultorio is None:
            raise CommandError(f"No existe el consultorio «{slug}».")
        ahora = timezone.now()
        for nombre, valor in resumen(consultorio, ahora - timedelta(days=dias), ahora).items():
            self.stdout.write(f"{nombre}: {'sin datos' if valor is None else valor}")
