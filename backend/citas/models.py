from django.contrib.postgres.constraints import ExclusionConstraint
from django.contrib.postgres.fields import DateTimeRangeField, RangeBoundary, RangeOperators
from django.db import models
from django.db.models import Func, Q

from agenda.models import Tratamiento
from consultorios.models import Consultorio, Profesional, Usuario


class Paciente(models.Model):
    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="pacientes")
    nombre = models.CharField(max_length=120)
    celular = models.CharField(max_length=40, help_text="Formato E.164: +51987654321")
    verificado_en = models.DateTimeField(null=True, blank=True)
    consentimiento_en = models.DateTimeField(null=True, blank=True)
    politica_version = models.CharField(
        max_length=20, blank=True, help_text="Versión de la política de datos que aceptó (settings.POLITICA_VERSION)."
    )
    acepta_publicidad_en = models.DateTimeField(
        null=True, blank=True, help_text="Consentimiento aparte para recibir promociones. Vacío: no se le envían."
    )
    inasistencias = models.PositiveIntegerField(default=0)
    bloqueado = models.BooleanField(default=False)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["nombre"]
        constraints = [models.UniqueConstraint(fields=["consultorio", "celular"], name="paciente_celular_unico")]

    def __str__(self) -> str:
        return f"{self.nombre} ({self.celular})"


class Estado(models.TextChoices):
    PENDIENTE = "pendiente", "Pendiente de verificación"
    POR_APROBAR = "por_aprobar", "Por confirmar"
    PROGRAMADA = "programada", "Programada"
    EN_CURSO = "en_curso", "En curso"
    TERMINADA = "terminada", "Terminada"
    EXPIRADA = "expirada", "Expirada"
    CANCELADA = "cancelada", "Cancelada"
    NO_ASISTIO = "no_asistio", "No asistió"


ESTADOS_ACTIVOS = [Estado.PENDIENTE, Estado.POR_APROBAR, Estado.PROGRAMADA, Estado.EN_CURSO]


class Origen(models.TextChoices):
    WEB = "web", "Web"
    DOCTOR = "doctor", "Doctor"


class TsTzRange(Func):
    function = "TSTZRANGE"
    output_field = DateTimeRangeField()


class Cita(models.Model):
    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="citas")
    paciente = models.ForeignKey(Paciente, on_delete=models.CASCADE, related_name="citas")
    tratamiento = models.ForeignKey(Tratamiento, on_delete=models.PROTECT, related_name="citas")
    profesional = models.ForeignKey(Profesional, on_delete=models.PROTECT, related_name="citas")
    inicio = models.DateTimeField()
    fin = models.DateTimeField(help_text="Fin de la atención prevista.")
    fin_ocupado = models.DateTimeField(help_text="Fin + margen: lo que realmente reserva el horario.")
    inicio_real = models.DateTimeField(null=True, blank=True)
    fin_real = models.DateTimeField(null=True, blank=True)
    minutos_extra = models.PositiveSmallIntegerField(default=0)
    demora_min = models.PositiveSmallIntegerField(
        default=0, help_text="«Me demoro» antes de iniciar: corre la hora estimada de esta cita y de las siguientes."
    )
    estado = models.CharField(max_length=12, choices=Estado.choices, default=Estado.PENDIENTE)
    origen = models.CharField(max_length=6, choices=Origen.choices, default=Origen.WEB)
    nombre_ingresado = models.CharField(
        max_length=120,
        blank=True,
        help_text="Nombre escrito en la reserva. Solo reemplaza al del paciente al verificar el número.",
    )
    codigo = models.CharField(max_length=10, blank=True)
    expira_en = models.DateTimeField(null=True, blank=True)
    token_gestion = models.CharField(max_length=64, unique=True)
    recordatorio_enviado_en = models.DateTimeField(null=True, blank=True)
    asistencia_confirmada = models.BooleanField(
        null=True, blank=True, help_text="Lo marca el doctor cuando el paciente responde su WhatsApp."
    )
    llegada_en = models.DateTimeField(null=True, blank=True, help_text="Cuándo llegó el cliente al local.")
    # Lo acordado al reservar: no cambia aunque el negocio cambie después el precio o la duración del servicio.
    servicio_nombre = models.CharField(max_length=80, blank=True)
    duracion_acordada_min = models.PositiveSmallIntegerField(null=True, blank=True)
    precio_referencia = models.PositiveIntegerField("precio de referencia (céntimos)", null=True, blank=True)
    precio_ofrecido = models.PositiveIntegerField("precio ofrecido por el cliente (céntimos)", null=True, blank=True)
    precio_acordado = models.PositiveIntegerField("precio acordado (céntimos)", null=True, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["inicio"]
        indexes = [
            models.Index(fields=["consultorio", "inicio"]),
            models.Index(fields=["estado", "expira_en"]),
        ]
        constraints = [
            # La garantía final contra dobles reservas: la base rechaza el cruce aunque lleguen a la vez.
            ExclusionConstraint(
                name="cita_sin_cruces",
                expressions=[
                    (TsTzRange("inicio", "fin_ocupado", RangeBoundary()), RangeOperators.OVERLAPS),
                    ("profesional", RangeOperators.EQUAL),
                ],
                condition=Q(estado__in=ESTADOS_ACTIVOS),
            ),
            models.UniqueConstraint(
                fields=["codigo"], condition=Q(estado=Estado.PENDIENTE), name="cita_codigo_unico_pendiente"
            ),
            models.CheckConstraint(
                condition=Q(inicio__lt=models.F("fin")) & Q(fin__lte=models.F("fin_ocupado")), name="cita_rango_valido"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.inicio:%d/%m %H:%M} · {self.get_estado_display()}"

    def save(self, *args, **kwargs):
        if self.profesional_id is None and self.consultorio_id is not None:
            self.profesional = self.consultorio.profesional_principal()
        if not self.servicio_nombre and self.tratamiento_id is not None:
            self.servicio_nombre = self.tratamiento.nombre
            if self.precio_referencia is None and self.tratamiento.precio_desde is not None:
                self.precio_referencia = int(round(self.tratamiento.precio_desde * 100))
        if self.duracion_acordada_min is None and self.inicio and self.fin:
            self.duracion_acordada_min = int((self.fin - self.inicio).total_seconds() // 60)
        super().save(*args, **kwargs)

    @property
    def precio_vigente(self) -> int | None:
        """Lo que se muestra al cliente: lo acordado, si no lo ofrecido, si no la referencia."""
        for valor in (self.precio_acordado, self.precio_ofrecido, self.precio_referencia):
            if valor is not None:
                return valor
        return None


class EventoCita(models.Model):
    """Auditoría (RF-34): quién cambió cada cita, cuándo y desde qué valor."""

    cita = models.ForeignKey(Cita, on_delete=models.CASCADE, related_name="eventos")
    tipo = models.CharField(max_length=20)
    valor_anterior = models.CharField(max_length=60, blank=True)
    valor_nuevo = models.CharField(max_length=60, blank=True)
    usuario = models.ForeignKey(Usuario, null=True, blank=True, on_delete=models.SET_NULL)
    origen = models.CharField(max_length=10, blank=True, help_text="app, sitio, panel o sistema.")
    request_id = models.CharField(max_length=36, blank=True)
    fecha = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["fecha", "id"]


class IntentoReserva(models.Model):
    """Límite de 5 intentos por IP por hora, sin Redis. Se guarda el hash, nunca la IP (RNF-09)."""

    ip_hash = models.CharField(max_length=64)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["ip_hash", "creado_en"])]


class ClaveIdempotencia(models.Model):
    """La respuesta guardada de cada Idempotency-Key durante 24 h (denticita/idempotencia.py)."""

    alcance = models.CharField(max_length=60, help_text="Cuenta de la app o huella de la IP del sitio.")
    clave = models.CharField(max_length=80)
    huella = models.CharField(max_length=64, help_text="Hash del método, la ruta y el cuerpo.")
    estado = models.PositiveSmallIntegerField(default=0, help_text="0 mientras se procesa.")
    respuesta = models.JSONField(null=True, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["alcance", "clave"], name="idempotencia_unica")]


class Adelanto(models.Model):
    """Adelanto con conciliación manual (Yape, Plin, efectivo, transferencia). Desarrollado y apagado:
    solo existe con PAGOS_ADELANTADOS=1 en la plataforma y la opción activa en el negocio."""

    class Metodo(models.TextChoices):
        YAPE = "yape", "Yape"
        PLIN = "plin", "Plin"
        EFECTIVO = "efectivo", "Efectivo"
        TRANSFERENCIA = "transferencia", "Transferencia"

    class EstadoAdelanto(models.TextChoices):
        PENDIENTE = "pendiente", "Pendiente de verificar"
        RECIBIDO = "recibido", "Recibido"
        DEVUELTO = "devuelto", "Devuelto"

    cita = models.ForeignKey(Cita, on_delete=models.CASCADE, related_name="adelantos")
    monto = models.PositiveIntegerField("monto (céntimos)")
    metodo = models.CharField(max_length=15, choices=Metodo.choices)
    estado = models.CharField(max_length=10, choices=EstadoAdelanto.choices, default=EstadoAdelanto.PENDIENTE)
    operacion = models.CharField("n.º de operación", max_length=40, blank=True)
    nota = models.CharField(max_length=200, blank=True)
    registrado_por = models.ForeignKey(Usuario, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    creado_en = models.DateTimeField(auto_now_add=True)
    conciliado_en = models.DateTimeField(null=True, blank=True)
    devuelto_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["creado_en"]
        constraints = [models.CheckConstraint(condition=Q(monto__gt=0), name="adelanto_monto_positivo")]
