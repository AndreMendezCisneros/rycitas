from django.contrib import admin

from citas import servicios
from citas.models import Cita, EventoCita, Paciente


class EventoInline(admin.TabularInline):
    model = EventoCita
    extra = 0
    can_delete = False
    readonly_fields = ("tipo", "valor_anterior", "valor_nuevo", "usuario", "fecha")

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Cita)
class CitaAdmin(admin.ModelAdmin):
    list_display = ("inicio", "consultorio", "paciente", "tratamiento", "estado", "origen")
    list_filter = ("estado", "origen", "consultorio")
    date_hierarchy = "inicio"
    readonly_fields = ("token_gestion", "codigo")
    inlines = [EventoInline]


@admin.action(description="Borrar datos personales (a pedido del paciente)")
def anonimizar(modeladmin, request, queryset):
    for paciente in queryset:
        servicios.anonimizar_paciente(paciente)


@admin.register(Paciente)
class PacienteAdmin(admin.ModelAdmin):
    list_display = ("nombre", "celular", "consultorio", "inasistencias", "bloqueado", "verificado_en")
    list_filter = ("bloqueado", "consultorio")
    search_fields = ("nombre", "celular")
    actions = [anonimizar]
