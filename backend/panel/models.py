from django.db import models


class EventoPanel(models.Model):
    """Auditoría del panel: quién creó, suspendió o cambió cada negocio, y cuándo."""

    usuario = models.ForeignKey("consultorios.Usuario", null=True, on_delete=models.SET_NULL, related_name="+")
    consultorio = models.ForeignKey(
        "consultorios.Consultorio", null=True, on_delete=models.SET_NULL, related_name="eventos_panel"
    )
    accion = models.CharField(max_length=40)
    detalle = models.CharField(max_length=300, blank=True)
    fecha = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-fecha", "-id"]

    def __str__(self) -> str:
        return f"{self.fecha:%d/%m %H:%M} {self.accion}"
