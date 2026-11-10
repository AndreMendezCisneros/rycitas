"""Crea los negocios ficticios de demostración: Sonrisa Wari (landing de RyCitas) y GlowClinic (sitio propio)."""
import os
from datetime import time
from decimal import Decimal

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from agenda.models import HorarioSemanal, Tratamiento
from consultorios.models import Consultorio, Profesional, Usuario

TRATAMIENTOS = [
    ("Evaluación", "Es mi primera vez / no sé qué necesito", "Revisión completa y plan de tratamiento.", 30, 5, "40"),
    ("Limpieza dental", "Quiero una limpieza", "Retiro de sarro y pulido.", 45, 10, "80"),
    ("Urgencia por dolor", "Tengo dolor", "Atención para aliviar el dolor lo antes posible.", 30, 10, "60"),
    ("Curación", "Tengo una caries o se me rompió un diente", "Restauración con resina.", 45, 5, "90"),
    ("Blanqueamiento", "Quiero blanquear mis dientes", "Sesión en consultorio.", 60, 10, "350"),
    ("Control de ortodoncia", "Tengo control de brackets", "Ajuste mensual.", 20, 5, "70"),
]


# GlowClinic usa su propio sitio web (sitios/visage-artisan-hub): sus servicios son los que ese sitio anuncia.
SERVICIOS_GLOW = [
    ("Consulta de evaluación", "Quiero una evaluación gratuita", 30, 0, "0"),
    ("Hydrafacial", "Quiero una limpieza profunda", 60, 10, "180"),
    ("Rejuvenecimiento Láser", "Quiero reducir arrugas o cicatrices", 45, 15, "450"),
    ("Peeling Químico", "Quiero eliminar manchas", 30, 10, "220"),
    ("Tratamiento de Acné", "Tengo acné", 60, 10, "200"),
    ("Bioestimulación Facial", "Quiero rejuvenecer mi piel (PRP)", 75, 15, "520"),
    ("Harmonización Facial", "Quiero armonizar mis rasgos", 60, 15, "900"),
]
EQUIPO_GLOW = [
    ("Dra. María González", "Dermatóloga"),
    ("Dr. Carlos Mendoza", "Cirujano plástico facial"),
    ("Lic. Ana Martínez", "Cosmetóloga"),
]


def crear_glowclinic(password: str) -> None:
    glow, _ = Consultorio.objects.update_or_create(
        slug="glowclinic",
        defaults={
            "rubro": "estetica",
            "nombre": "GlowClinic",
            "doctor_nombre": EQUIPO_GLOW[0][0],
            "direccion": "Av. Larco 505, Miraflores (dirección ficticia)",
            "mapa_url": "https://maps.google.com/?q=Miraflores+Lima",
            "whatsapp": "51900000002",
            "publicado": True,
            "sitio_propio": "visage-artisan-hub",
            "opciones": {"modo_agenda": "por_profesional", "elegir_profesional": True},
            "contenido_sitio": {"color_acento": "#32b8c6", "formas_de_pago": ["Efectivo", "Yape", "Tarjeta"]},
        },
    )
    principal = glow.profesional_principal()
    principal.nombre, principal.detalle = EQUIPO_GLOW[0]
    principal.save()
    for orden, (nombre, detalle) in enumerate(EQUIPO_GLOW[1:], start=1):
        Profesional.objects.update_or_create(consultorio=glow, nombre=nombre, defaults={"detalle": detalle, "orden": orden})
    for orden, (nombre, motivo, duracion, margen, precio) in enumerate(SERVICIOS_GLOW):
        Tratamiento.objects.update_or_create(
            consultorio=glow, nombre=nombre,
            defaults={"motivo_paciente": motivo, "duracion_min": duracion, "margen_min": margen,
                      "precio_desde": Decimal(precio) if precio != "0" else None, "orden": orden},
        )
    if not HorarioSemanal.objects.filter(consultorio=glow).exists():
        filas = [HorarioSemanal(consultorio=glow, dia_semana=d, hora_inicio=time(9), hora_fin=time(19)) for d in range(5)]
        filas.append(HorarioSemanal(consultorio=glow, dia_semana=5, hora_inicio=time(9), hora_fin=time(14)))
        HorarioSemanal.objects.bulk_create(filas)
    recepcion, creado = Usuario.objects.get_or_create(correo="recepcion@glowclinic.test", defaults={"consultorio": glow})
    if creado:
        recepcion.set_password(password)
        recepcion.save()


class Command(BaseCommand):
    help = "Crea datos de demostración: nunca en producción."

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("crear_demo solo funciona con DJANGO_DEBUG=1.")

        consultorio, _ = Consultorio.objects.update_or_create(
            slug="sonrisa-wari",
            defaults={
                "nombre": "Sonrisa Wari",
                "doctor_nombre": "Dra. Ana Quispe Rojas",
                "colegiatura": "00000 (ficticio)",
                "presentacion": (
                    "Atiendo a familias de Huamanga desde hace 12 años. Te explico cada paso con palabras "
                    "simples y sin apuros. Este consultorio es ficticio: sirve para probar la reserva."
                ),
                "direccion": "Jr. Asamblea 123, Ayacucho (dirección ficticia)",
                "mapa_url": "https://maps.google.com/?q=Plaza+de+Armas+Ayacucho",
                "whatsapp": "51900000001",
                "publicado": True,
                "contenido_sitio": {
                    "formas_de_pago": ["Efectivo", "Yape", "Plin"],
                    "anos_practica": 12,
                    "publico": "Niños, adultos y personas mayores",
                    "referencias": "A media cuadra de la Plaza de Armas (referencia ficticia)",
                },
            },
        )
        for orden, (nombre, motivo, descripcion, duracion, margen, precio) in enumerate(TRATAMIENTOS):
            Tratamiento.objects.update_or_create(
                consultorio=consultorio,
                nombre=nombre,
                defaults={
                    "motivo_paciente": motivo,
                    "descripcion": descripcion,
                    "duracion_min": duracion,
                    "margen_min": margen,
                    "precio_desde": Decimal(precio),
                    "orden": orden,
                },
            )
        if not HorarioSemanal.objects.filter(consultorio=consultorio).exists():
            filas = []
            for dia in range(5):
                filas += [
                    HorarioSemanal(consultorio=consultorio, dia_semana=dia, hora_inicio=time(9), hora_fin=time(13)),
                    HorarioSemanal(consultorio=consultorio, dia_semana=dia, hora_inicio=time(15), hora_fin=time(19)),
                ]
            filas.append(HorarioSemanal(consultorio=consultorio, dia_semana=5, hora_inicio=time(9), hora_fin=time(14)))
            HorarioSemanal.objects.bulk_create(filas)

        password = os.environ.get("DEMO_PASSWORD", "demo-denticita-2026")
        doctor, creado = Usuario.objects.get_or_create(correo="doctora@sonrisawari.test", defaults={"consultorio": consultorio})
        if creado:
            doctor.set_password(password)
            doctor.save()
        admin, creado = Usuario.objects.get_or_create(
            correo="admin@denticita.test", defaults={"is_staff": True, "is_superuser": True}
        )
        if creado:
            admin.set_password(password)
            admin.save()
        crear_glowclinic(password)
        self.stdout.write(self.style.SUCCESS(f"Sitio: http://sonrisa-wari.localhost:8000  ·  clave: {password}"))
        self.stdout.write(self.style.SUCCESS("Sitio propio: http://glowclinic.localhost:8000  ·  recepcion@glowclinic.test"))
