"""Cuenta del cliente final en la app («Quiero reservar»), fidelización y cupones.

El cliente no se copia en cada negocio: se vincula por su celular con los `Paciente` que ya existen. Los sellos se
guardan por (negocio, celular), así se ganan aunque la persona todavía no tenga la app y aparecen al registrarse.
"""
import secrets

from django.db import models

from consultorios.models import Consultorio


def codigo_referido() -> str:
    alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # sin 0/O ni 1/I: se dicta por teléfono sin confusiones
    return "".join(secrets.choice(alfabeto) for _ in range(6))


class Cliente(models.Model):
    nombre = models.CharField(max_length=120)
    correo = models.EmailField(unique=True)
    celular = models.CharField(max_length=40, db_index=True, help_text="E.164: +51987654321")
    correo_verificado_en = models.DateTimeField(null=True, blank=True)
    celular_verificado_en = models.DateTimeField(
        null=True, blank=True, help_text="Al abrir en la app el enlace de una cita enviado a ese WhatsApp."
    )
    politica_version = models.CharField(max_length=20, blank=True, help_text="Versión de la política que aceptó.")
    consentimiento_en = models.DateTimeField(null=True, blank=True)
    acepta_publicidad_en = models.DateTimeField(
        null=True, blank=True, help_text="Consentimiento aparte para recibir promociones. Vacío: no se le envían."
    )
    codigo_referido = models.CharField(max_length=8, unique=True, default=codigo_referido)
    referido_por = models.ForeignKey("self", null=True, blank=True, on_delete=models.SET_NULL, related_name="referidos")
    referido_premiado_en = models.DateTimeField(null=True, blank=True)
    silenciados = models.ManyToManyField(Consultorio, blank=True, related_name="clientes_silenciados")
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["nombre"]

    def __str__(self) -> str:
        return f"{self.nombre} <{self.correo}>"


class CodigoCorreo(models.Model):
    """Solo con VERIFICAR_CLIENTES=1: código de 6 dígitos por correo, vence en 10 min, 5 intentos."""

    cliente = models.ForeignKey(Cliente, on_delete=models.CASCADE, related_name="codigos")
    codigo_hash = models.CharField(max_length=64)
    expira_en = models.DateTimeField()
    intentos = models.PositiveSmallIntegerField(default=0)
    usado_en = models.DateTimeField(null=True, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True)


class SesionCliente(models.Model):
    """Renovación rotativa, igual que la del negocio (detecta el reuso de un token robado)."""

    cliente = models.ForeignKey(Cliente, on_delete=models.CASCADE, related_name="sesiones")
    familia = models.UUIDField(db_index=True)
    token_hash = models.CharField(max_length=64, unique=True)
    expira_en = models.DateTimeField()
    usado_en = models.DateTimeField(null=True, blank=True)
    revocado = models.BooleanField(default=False)
    creado_en = models.DateTimeField(auto_now_add=True)


class DispositivoCliente(models.Model):
    cliente = models.ForeignKey(Cliente, on_delete=models.CASCADE, related_name="dispositivos")
    token_fcm = models.CharField(max_length=512, unique=True)
    plataforma = models.CharField(max_length=20, default="android")
    ultimo_uso = models.DateTimeField(auto_now=True)


class Sello(models.Model):
    class Motivo(models.TextChoices):
        VISITA = "visita", "Visita"
        PUNTUAL = "puntual", "Llegó a tiempo"
        REFERIDO = "referido", "Trajo a un amigo"
        AJUSTE = "ajuste", "Regalo del negocio"

    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="sellos")
    celular = models.CharField(max_length=40)
    motivo = models.CharField(max_length=10, choices=Motivo.choices)
    cita = models.ForeignKey("citas.Cita", null=True, blank=True, on_delete=models.SET_NULL, related_name="sellos")
    canje = models.ForeignKey(
        "Canje", null=True, blank=True, on_delete=models.SET_NULL, related_name="sellos",
        help_text="Vacío: el sello aún cuenta para el próximo premio.",
    )
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["consultorio", "celular"])]
        constraints = [
            # Una cita da como mucho un sello de cada tipo, aunque se marque «Terminar» dos veces.
            models.UniqueConstraint(fields=["cita", "motivo"], name="sello_unico_por_cita"),
        ]


class Canje(models.Model):
    """La tarjeta se llenó y el negocio entregó el premio."""

    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="canjes")
    celular = models.CharField(max_length=40)
    premio = models.CharField(max_length=120)
    creado_en = models.DateTimeField(auto_now_add=True)


class Segmento(models.TextChoices):
    TODOS = "todos", "Todos los clientes"
    INACTIVOS = "inactivos", "No vienen hace 60 días"
    ORO = "oro", "Nivel Oro"
    NUEVOS = "nuevos", "Vinieron una sola vez"


class Cupon(models.Model):
    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="cupones")
    codigo = models.CharField(max_length=20)
    titulo = models.CharField(max_length=80, help_text="«20 % en tu limpieza facial»")
    descuento_pct = models.PositiveSmallIntegerField(null=True, blank=True)
    descuento_monto = models.PositiveIntegerField("descuento fijo (céntimos)", null=True, blank=True)
    tratamiento = models.ForeignKey(
        "agenda.Tratamiento", null=True, blank=True, on_delete=models.SET_NULL, help_text="Vacío: cualquier servicio."
    )
    segmento = models.CharField(max_length=10, choices=Segmento.choices, default=Segmento.TODOS)
    vence_el = models.DateField()
    usos_max = models.PositiveIntegerField(null=True, blank=True, help_text="Vacío: sin límite.")
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-creado_en"]
        constraints = [models.UniqueConstraint(fields=["consultorio", "codigo"], name="cupon_codigo_unico")]

    def __str__(self) -> str:
        return f"{self.codigo} · {self.titulo}"


class CuponUsado(models.Model):
    """El cliente eligió el cupón al reservar; el negocio lo ve en la cita."""

    cupon = models.ForeignKey(Cupon, on_delete=models.CASCADE, related_name="usos")
    cita = models.OneToOneField("citas.Cita", on_delete=models.CASCADE, related_name="cupon_usado")
    celular = models.CharField(max_length=40)
    creado_en = models.DateTimeField(auto_now_add=True)


class Campana(models.Model):
    """Mensaje del negocio a sus clientes (máx. 2 por semana): push a quienes tienen la app y enlaces wa.me para
    enviar a mano al resto."""

    consultorio = models.ForeignKey(Consultorio, on_delete=models.CASCADE, related_name="campanas")
    titulo = models.CharField(max_length=80)
    mensaje = models.CharField(max_length=300)
    segmento = models.CharField(max_length=10, choices=Segmento.choices, default=Segmento.TODOS)
    cupon = models.ForeignKey(Cupon, null=True, blank=True, on_delete=models.SET_NULL, related_name="campanas")
    destinatarios = models.PositiveIntegerField(default=0)
    con_app = models.PositiveIntegerField(default=0)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-creado_en"]
