from django.db import models


class EventoSitio(models.Model):
    """Paso del embudo de reserva. Sin datos personales: `sesion` es un valor al azar que dura lo que la pestaña."""

    class Tipo(models.TextChoices):
        VISITA = "visita", "Visita"
        PASO_1 = "paso_1", "Reserva iniciada"
        PASO_2 = "paso_2", "Eligió motivo"
        PASO_3 = "paso_3", "Eligió hora"
        PASO_4 = "paso_4", "Envió datos"
        CONFIRMADA = "confirmada", "Vio su cita confirmada"

    consultorio = models.ForeignKey("consultorios.Consultorio", on_delete=models.CASCADE, related_name="eventos_sitio")
    sesion = models.CharField(max_length=40)
    tipo = models.CharField(max_length=12, choices=Tipo.choices)
    creado_en = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["consultorio", "sesion", "tipo"], name="evento_unico_por_sesion")]
