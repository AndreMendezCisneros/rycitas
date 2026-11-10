from django.db import models
from django.utils.text import slugify

from consultorios.models import Consultorio


class Tratamiento(models.Model):
    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="tratamientos")
    nombre = models.CharField(max_length=80)
    slug = models.SlugField(max_length=90, blank=True)
    motivo_paciente = models.CharField(
        "motivo que ve el paciente", max_length=80, blank=True, help_text="Por ejemplo: «Tengo dolor»."
    )
    descripcion = models.CharField(max_length=200, blank=True)
    indicaciones = models.CharField(
        max_length=200, blank=True, help_text="Va en el mensaje de confirmación. Por ejemplo: «Ven 10 min antes»."
    )
    duracion_min = models.PositiveSmallIntegerField("duración (min)", default=30)
    margen_min = models.PositiveSmallIntegerField("margen (min)", default=0)
    precio_desde = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    reservable = models.BooleanField("reservable en línea", default=True)
    visible = models.BooleanField("visible en el sitio", default=True)
    orden = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["orden", "nombre"]
        constraints = [
            models.UniqueConstraint(fields=["consultorio", "slug"], name="tratamiento_slug_unico_por_consultorio"),
            models.CheckConstraint(condition=models.Q(duracion_min__gt=0), name="tratamiento_duracion_positiva"),
        ]

    def __str__(self) -> str:
        return self.nombre

    def save(self, *args, **kwargs):
        if not self.slug:
            base = slugify(self.nombre)[:80] or "tratamiento"
            slug, n = base, 2
            while Tratamiento.objects.filter(consultorio=self.consultorio, slug=slug).exclude(pk=self.pk).exists():
                slug, n = f"{base}-{n}", n + 1
            self.slug = slug
        super().save(*args, **kwargs)


class HorarioSemanal(models.Model):
    """Varias filas por día = varios tramos."""

    DIAS = [
        (0, "Lunes"),
        (1, "Martes"),
        (2, "Miércoles"),
        (3, "Jueves"),
        (4, "Viernes"),
        (5, "Sábado"),
        (6, "Domingo"),
    ]

    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="horarios")
    profesional = models.ForeignKey(
        "consultorios.Profesional",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="horarios",
        help_text="Vacío: horario del negocio, para todo profesional sin horario propio.",
    )
    dia_semana = models.PositiveSmallIntegerField(choices=DIAS)
    hora_inicio = models.TimeField()
    hora_fin = models.TimeField()

    class Meta:
        ordering = ["dia_semana", "hora_inicio"]
        constraints = [
            models.CheckConstraint(condition=models.Q(hora_inicio__lt=models.F("hora_fin")), name="horario_tramo_valido"),
        ]

    def __str__(self) -> str:
        return f"{self.get_dia_semana_display()} {self.hora_inicio:%H:%M}-{self.hora_fin:%H:%M}"


class Bloqueo(models.Model):
    """Puntual o de días completos; los recurrentes llegan en la fase 2."""

    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="bloqueos")
    profesional = models.ForeignKey(
        "consultorios.Profesional",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="bloqueos",
        help_text="Vacío: cierra todo el negocio.",
    )
    inicio = models.DateTimeField()
    fin = models.DateTimeField()
    motivo = models.CharField(max_length=120, blank=True)

    class Meta:
        ordering = ["inicio"]
        indexes = [models.Index(fields=["consultorio", "inicio", "fin"])]
        constraints = [
            models.CheckConstraint(condition=models.Q(inicio__lt=models.F("fin")), name="bloqueo_rango_valido"),
        ]

    def __str__(self) -> str:
        return f"{self.inicio:%d/%m %H:%M} {self.motivo}".strip()
