from django.db import models

from citas.models import Cita


class MensajeEntrante(models.Model):
    """Lo que llega por el webhook. `wamid` único evita procesar dos veces el mismo mensaje."""

    wamid = models.CharField(max_length=200, unique=True)
    celular = models.CharField(max_length=20)
    texto = models.TextField(blank=True)
    recibido_en = models.DateTimeField(auto_now_add=True)
    cita = models.ForeignKey(Cita, null=True, blank=True, on_delete=models.SET_NULL, related_name="mensajes")


class AvisoPendiente(models.Model):
    """Outbox de avisos push (análisis RYJEC, mejora 10): si Firebase falla, el aviso se reintenta y no se pierde.

    `clave` evita duplicados: el mismo aviso para la misma cita y el mismo momento se encola una sola vez.
    """

    REINTENTOS_MIN = [1, 5, 15, 60]

    consultorio = models.ForeignKey("consultorios.Consultorio", on_delete=models.CASCADE, related_name="avisos")
    profesional = models.ForeignKey(
        "consultorios.Profesional", null=True, blank=True, on_delete=models.SET_NULL, related_name="+",
        help_text="Si hay, solo a sus cuentas y a los encargados; si no, a todas las cuentas del negocio.",
    )
    solo_profesional = models.BooleanField(
        default=False,
        help_text="Solo a las cuentas del profesional (si no tiene ninguna, a los encargados). Ej.: «en 30 min».",
    )
    clave = models.CharField(max_length=120, unique=True)
    titulo = models.CharField(max_length=120)
    cuerpo = models.CharField(max_length=300)
    datos = models.JSONField(default=dict, blank=True)
    intentos = models.PositiveSmallIntegerField(default=0)
    proximo_intento = models.DateTimeField(db_index=True)
    enviado_en = models.DateTimeField(null=True, blank=True)
    error = models.CharField(max_length=200, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["enviado_en", "proximo_intento"])]
