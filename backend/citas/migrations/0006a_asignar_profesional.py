"""Datos de 0006: cada negocio existente queda con su profesional principal."""
from django.db import migrations


def asignar_profesional(apps, schema_editor):
    """Cada negocio existente queda con un profesional (su doctor) y todas sus citas pasan a él.

    También se fija lo acordado en cada cita: nombre del servicio, duración y precio de referencia.
    """
    Consultorio = apps.get_model("consultorios", "Consultorio")
    Profesional = apps.get_model("consultorios", "Profesional")
    Cita = apps.get_model("citas", "Cita")
    for c in Consultorio.objects.all():
        principal = Profesional.objects.filter(consultorio=c).order_by("orden", "id").first()
        if principal is None:
            principal = Profesional.objects.create(
                consultorio=c, nombre=c.doctor_nombre or c.nombre, detalle=c.colegiatura, foto=c.foto
            )
        Cita.objects.filter(consultorio=c, profesional__isnull=True).update(profesional=principal)
    for cita in Cita.objects.select_related("tratamiento").filter(servicio_nombre=""):
        cita.servicio_nombre = cita.tratamiento.nombre
        cita.duracion_acordada_min = int((cita.fin - cita.inicio).total_seconds() // 60)
        if cita.tratamiento.precio_desde is not None:
            cita.precio_referencia = int(round(cita.tratamiento.precio_desde * 100))
        cita.save(update_fields=["servicio_nombre", "duracion_acordada_min", "precio_referencia"])


class Migration(migrations.Migration):

    dependencies = [
        ('citas', '0006_cita_profesional'),
    ]

    operations = [
        migrations.RunPython(asignar_profesional, migrations.RunPython.noop),
    ]
