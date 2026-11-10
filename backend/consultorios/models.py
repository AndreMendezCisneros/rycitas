from django.conf import settings
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.core.exceptions import ValidationError
from django.core.validators import RegexValidator
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver

from consultorios.rubros import RUBRO_CHOICES, rubro

# Lo que el panel enciende o apaga por negocio. `llegar_antes_min` en None toma el valor del tipo de negocio.
OPCIONES_POR_DEFECTO = {
    "modo_agenda": "compartida",  # compartida | por_profesional
    "elegir_profesional": True,  # solo cuenta con modo por_profesional
    "precio_ofertable": False,  # el cliente puede ofrecer otro precio al reservar
    "adelantos": False,  # además exige PAGOS_ADELANTADOS=1 en la plataforma
    "llegar_antes_min": None,
    "tolerancia_inasistencia_min": 15,
    "recordar_pendientes_horas": 2,
    "sesion_web_min": 60,
    # La agenda del día se divide en turnos: cada uno va desde el fin del anterior hasta «hasta» (el último, 24:00).
    "turnos": [{"nombre": "Mañana", "hasta": "13:00"}, {"nombre": "Tarde", "hasta": "24:00"}],
    # Push al profesional N minutos antes de cada cita confirmada (0: apagado).
    "recordar_cita_min": 30,
    # Tarjeta de sellos (app del cliente): un sello por visita terminada; al juntar la meta, el premio.
    "fidelidad_activa": False,
    "fidelidad_meta": 5,
    "fidelidad_premio": "20 % de descuento en tu próxima visita",
    "sello_puntualidad": True,  # sello extra si llegó a tiempo
}

# Avisos push que cada cuenta puede apagar para sí (Ajustes → Notificaciones de la app).
TIPOS_DE_AVISO = {
    "por_aprobar": "Reservas por confirmar",
    "nueva_cita": "Citas nuevas",
    "cita_proxima": "Antes de cada cita",
    "recordatorios": "Agenda de mañana (8 p. m.)",
}

MAX_TURNOS = 3


def _minutos(hhmm: str) -> int:
    horas, minutos = str(hhmm).strip().split(":")
    total = int(horas) * 60 + int(minutos)
    if not 0 < total <= 24 * 60 or int(minutos) >= 60:
        raise ValueError(hhmm)
    return total


def validar_turnos(turnos) -> list[dict]:
    """Normaliza la lista de turnos o lanza ValueError con un mensaje para mostrar.

    De 1 a 3 turnos, con nombre y hora de corte creciente; el último siempre llega a las 24:00.
    """
    if not isinstance(turnos, list) or not 1 <= len(turnos) <= MAX_TURNOS:
        raise ValueError(f"Define entre 1 y {MAX_TURNOS} turnos.")
    limpios, anterior = [], 0
    for i, turno in enumerate(turnos):
        nombre = str((turno or {}).get("nombre", "")).strip()[:20]
        if not nombre:
            raise ValueError("Cada turno necesita un nombre.")
        ultimo = i == len(turnos) - 1
        try:
            hasta = 24 * 60 if ultimo else _minutos(turno.get("hasta", ""))
        except (ValueError, AttributeError):
            raise ValueError(f"La hora de fin de «{nombre}» no es válida (usa HH:MM).") from None
        if hasta <= anterior:
            raise ValueError("Cada turno debe terminar después del anterior.")
        limpios.append({"nombre": nombre, "hasta": f"{hasta // 60:02d}:{hasta % 60:02d}"})
        anterior = hasta
    return limpios


def turnos_con_rango(turnos: list[dict]) -> list[dict]:
    """[{nombre, desde, hasta}] en minutos del día, para agrupar citas."""
    resultado, desde = [], 0
    for t in turnos:
        hasta = _minutos(t["hasta"])
        resultado.append({"nombre": t["nombre"], "desde": desde, "hasta": hasta})
        desde = hasta
    return resultado

REGLAS_POR_DEFECTO = {
    "anticipacion_min_horas": 2,
    "dias_maximos": 30,
    "limite_cancelacion_horas": 12,
    "margen_entre_citas_min": 0,
    "paso_min": 15,
}

CONTENIDO_POR_DEFECTO = {
    "logo": "",
    "foto_consultorio": "",
    "formas_de_pago": [],
    "anos_practica": None,
    "publico": "",
    "referencias": "",
    "bloques_confianza": [
        {"titulo": "Bioseguridad", "texto": "Instrumental esterilizado para cada paciente y superficies desinfectadas entre citas."},
        {"titulo": "Materiales de un solo uso", "texto": "Guantes, mascarillas, baberos y agujas se abren frente a ti y se desechan al terminar."},
        {"titulo": "Sala sin aglomeración", "texto": "Con cita y hora estimada, esperas poco y sin mucha gente alrededor."},
    ],
    "faq_ocultas": [],
    "color_acento": "",  # «#32b8c6»: el color de la reserva; vacío usa el del tipo de negocio
}


def validar_subdominio(valor: str) -> None:
    if valor in settings.SUBDOMINIOS_RESERVADOS:
        raise ValidationError(f"El subdominio «{valor}» está reservado por la plataforma.")


class Consultorio(models.Model):
    slug = models.SlugField(
        "subdominio",
        max_length=40,
        unique=True,
        validators=[RegexValidator(r"^[a-z0-9]+(-[a-z0-9]+)*$", "Solo minúsculas, números y guiones."), validar_subdominio],
    )
    nombre = models.CharField(max_length=120)
    doctor_nombre = models.CharField("nombre del doctor", max_length=120)
    colegiatura = models.CharField(max_length=30, blank=True)
    foto = models.ImageField(upload_to="doctores/", blank=True)
    presentacion = models.TextField("presentación", blank=True)
    direccion = models.CharField("dirección", max_length=200)
    mapa_url = models.URLField("enlace del mapa", blank=True)
    whatsapp = models.CharField(
        "WhatsApp del consultorio",
        max_length=12,
        help_text="Solo dígitos con código de país, por ejemplo 51987654321.",
        validators=[RegexValidator(r"^51\d{9}$", "Usa el formato 51987654321.")],
    )
    reglas = models.JSONField(default=dict, blank=True, help_text="Vacío usa los valores por defecto.")
    contenido_sitio = models.JSONField(
        "contenido del sitio", default=dict, blank=True, help_text="Se edita con los campos de este formulario."
    )
    publicado = models.BooleanField(
        default=False, help_text="Sin publicar muestra «Sitio en preparación» y no acepta reservas."
    )
    activo = models.BooleanField(default=True)
    rubro = models.CharField("tipo de negocio", max_length=20, choices=RUBRO_CHOICES, default="odontologia")
    opciones = models.JSONField(default=dict, blank=True, help_text="Vacío usa los valores por defecto.")
    suspendido = models.BooleanField(
        default=False, help_text="Suspendido: el sitio no acepta reservas, pero la app y las citas siguen intactas."
    )
    servicio_hasta = models.DateField("servicio pagado hasta", null=True, blank=True)
    sitio_propio = models.CharField(
        "sitio propio", max_length=60, blank=True,
        help_text="Carpeta en sitios_propios/ con el sitio web completo del negocio. Vacío usa la landing de RyCitas.",
    )
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["nombre"]

    def __str__(self) -> str:
        return self.nombre

    @property
    def reglas_efectivas(self) -> dict:
        return {**REGLAS_POR_DEFECTO, **(self.reglas or {})}

    @property
    def tipo(self) -> dict:
        return rubro(self.rubro)

    @property
    def vocabulario(self) -> dict:
        return self.tipo["vocabulario"]

    @property
    def opciones_efectivas(self) -> dict:
        efectivas = {**OPCIONES_POR_DEFECTO, **(self.opciones or {})}
        if efectivas["llegar_antes_min"] is None:
            efectivas["llegar_antes_min"] = self.tipo["llegar_antes_min"]
        efectivas["adelantos"] = bool(efectivas["adelantos"] and settings.PAGOS_ADELANTADOS)
        if efectivas["modo_agenda"] != "por_profesional":
            efectivas["elegir_profesional"] = False
        return efectivas

    @property
    def acepta_reservas(self) -> bool:
        return self.publicado and self.activo and not self.suspendido

    def profesional_principal(self) -> "Profesional":
        """Todo negocio tiene al menos uno; se crea con el negocio a partir del nombre del doctor."""
        principal = self.profesionales.order_by("orden", "id").first()
        if principal is None:
            principal = Profesional.objects.create(consultorio=self, nombre=self.doctor_nombre or self.nombre)
        return principal

    @property
    def contenido(self) -> dict:
        # Los bloques de confianza por defecto dependen del tipo de negocio: una barbería no habla de bioseguridad.
        base = {**CONTENIDO_POR_DEFECTO, "bloques_confianza": self.tipo["confianza"]}
        return {**base, **(self.contenido_sitio or {})}

    @property
    def iniciales_doctor(self) -> str:
        """Monograma cuando aún no hay foto: «Dra. Ana Quispe Rojas» da «AQ»."""
        return iniciales(self.doctor_nombre)


def iniciales(nombre: str) -> str:
    palabras = [p for p in nombre.split() if not p.endswith(".")]
    return "".join(p[0] for p in palabras[:2]).upper()


class Profesional(models.Model):
    """Quien atiende. Con agenda compartida hay uno solo; con «un profesional por cuenta», uno por barbero o doctor.

    Cada profesional tiene su propia agenda: dos profesionales pueden atender a la misma hora.
    """

    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="profesionales")
    nombre = models.CharField(max_length=120)
    detalle = models.CharField(max_length=60, blank=True, help_text="Colegiatura, especialidad o similar.")
    foto = models.ImageField(upload_to="profesionales/", blank=True)
    servicios = models.ManyToManyField(
        "agenda.Tratamiento", blank=True, related_name="profesionales", help_text="Vacío: hace todos los servicios."
    )
    activo = models.BooleanField(default=True)
    orden = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["orden", "id"]
        verbose_name_plural = "profesionales"

    def __str__(self) -> str:
        return self.nombre

    @property
    def iniciales(self) -> str:
        return iniciales(self.nombre)

    def hace(self, tratamiento) -> bool:
        ids = [t.pk for t in self.servicios.all()]
        return not ids or tratamiento.pk in ids


@receiver(post_save, sender=Consultorio)
def _crear_profesional_principal(sender, instance, created, raw=False, **kwargs):
    if created and not raw:
        Profesional.objects.create(consultorio=instance, nombre=instance.doctor_nombre or instance.nombre,
                                   detalle=instance.colegiatura)


class UsuarioManager(BaseUserManager):
    def create_user(self, correo, password=None, **extra):
        usuario = self.model(correo=self.normalize_email(correo).lower(), **extra)
        usuario.set_password(password)
        usuario.save(using=self._db)
        return usuario

    def create_superuser(self, correo, password=None, **extra):
        extra.update(is_staff=True, is_superuser=True)
        return self.create_user(correo, password, **extra)


class Usuario(AbstractBaseUser, PermissionsMixin):
    """Un doctor por consultorio en el MVP; el administrador de la plataforma no tiene consultorio."""

    correo = models.EmailField(unique=True)
    consultorio = models.ForeignKey(Consultorio, null=True, blank=True, on_delete=models.CASCADE, related_name="usuarios")
    profesional = models.ForeignKey(
        Profesional,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="cuentas",
        help_text="Vacío: encargado o recepción, ve toda la agenda.",
    )
    nombre = models.CharField(max_length=120, blank=True)
    activo = models.BooleanField(default=True)
    avisos_apagados = models.JSONField(
        default=list, blank=True, help_text="Tipos de aviso push que esta cuenta no quiere recibir."
    )
    is_staff = models.BooleanField("acceso al panel", default=False)
    intentos_fallidos = models.PositiveSmallIntegerField(default=0)
    bloqueado_hasta = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "correo"
    objects = UsuarioManager()

    def __str__(self) -> str:
        return self.correo

    @property
    def is_active(self) -> bool:
        return self.activo


class Dispositivo(models.Model):
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name="dispositivos")
    token_fcm = models.CharField(max_length=512, unique=True)
    plataforma = models.CharField(max_length=20, default="android")
    ultimo_uso = models.DateTimeField(auto_now=True)


class SesionRenovacion(models.Model):
    """Token de renovación rotativo (RNF-07). Solo se guarda el hash.

    Reusar un token ya gastado revoca toda la familia: señal de que alguien lo copió.
    """

    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name="sesiones")
    familia = models.UUIDField(db_index=True)
    token_hash = models.CharField(max_length=64, unique=True)
    expira_en = models.DateTimeField()
    usado_en = models.DateTimeField(null=True, blank=True)
    revocado = models.BooleanField(default=False)
    creado_en = models.DateTimeField(auto_now_add=True)
