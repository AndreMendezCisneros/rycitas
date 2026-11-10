"""Sin verificación por WhatsApp, las pre-reservas que esperaban el código pasan a «Por confirmar» (las confirma el doctor)."""
from django.conf import settings
from django.db import migrations


def a_por_confirmar(apps, schema_editor):
    if settings.VERIFICACION_WHATSAPP:
        return
    Cita = apps.get_model("citas", "Cita")
    Cita.objects.filter(estado="pendiente").update(estado="por_aprobar", codigo="", expira_en=None)


class Migration(migrations.Migration):
    dependencies = [("citas", "0003_confirmacion_manual")]
    operations = [migrations.RunPython(a_por_confirmar, migrations.RunPython.noop)]
