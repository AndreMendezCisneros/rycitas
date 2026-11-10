"""Segunda mitad de 0006: con todas las citas ya asignadas, el profesional pasa a ser obligatorio y la
restricción contra cruces se aplica por profesional."""
import citas.models
import django.contrib.postgres.constraints
import django.contrib.postgres.fields.ranges
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('citas', '0006a_asignar_profesional'),
    ]

    operations = [
        migrations.AlterField(
            model_name='cita',
            name='profesional',
            field=models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='citas', to='consultorios.profesional'),
        ),
        migrations.AddConstraint(
            model_name='cita',
            constraint=django.contrib.postgres.constraints.ExclusionConstraint(condition=models.Q(('estado__in', ['pendiente', 'por_aprobar', 'programada', 'en_curso'])), expressions=[(citas.models.TsTzRange('inicio', 'fin_ocupado', django.contrib.postgres.fields.ranges.RangeBoundary()), '&&'), ('profesional', '=')], name='cita_sin_cruces'),
        ),
    ]
