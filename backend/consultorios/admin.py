from datetime import timedelta

from django import forms
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.utils import timezone
from django.utils.html import format_html_join
from django.utils.safestring import mark_safe

from agenda.models import Bloqueo, HorarioSemanal, Tratamiento
from consultorios.models import CONTENIDO_POR_DEFECTO, Consultorio, Usuario
from sitio.cache import purgar_sitio
from sitio.contenido import PREGUNTAS
from sitio.imagenes import a_webp
from sitio.metricas import resumen


class TratamientoInline(admin.TabularInline):
    model = Tratamiento
    extra = 1
    fields = ("nombre", "motivo_paciente", "duracion_min", "margen_min", "precio_desde", "reservable", "visible", "orden")


class HorarioInline(admin.TabularInline):
    model = HorarioSemanal
    extra = 1


class BloqueoInline(admin.TabularInline):
    model = Bloqueo
    extra = 0


class ConsultorioForm(forms.ModelForm):
    """Los textos y fotos del sitio van en `contenido_sitio`; aquí se editan como campos normales."""

    logo = forms.ImageField(required=False)
    quitar_logo = forms.BooleanField(required=False)
    foto_consultorio = forms.ImageField(required=False, label="Foto del consultorio")
    quitar_foto_consultorio = forms.BooleanField(required=False)
    formas_de_pago = forms.CharField(required=False, help_text="Separadas por comas: Efectivo, Yape, Plin.")
    anos_practica = forms.IntegerField(required=False, min_value=0, max_value=70, label="Años de práctica")
    publico = forms.CharField(required=False, label="Público que atiende", max_length=120)
    referencias = forms.CharField(required=False, label="Referencias de la dirección", max_length=200)
    bloque_1_titulo = forms.CharField(required=False, max_length=60)
    bloque_1_texto = forms.CharField(required=False, widget=forms.Textarea(attrs={"rows": 2}), max_length=200)
    bloque_2_titulo = forms.CharField(required=False, max_length=60)
    bloque_2_texto = forms.CharField(required=False, widget=forms.Textarea(attrs={"rows": 2}), max_length=200)
    bloque_3_titulo = forms.CharField(required=False, max_length=60)
    bloque_3_texto = forms.CharField(required=False, widget=forms.Textarea(attrs={"rows": 2}), max_length=200)
    color_acento = forms.RegexField(
        regex=r"^(#[0-9a-fA-F]{6})?$", required=False, max_length=7, label="Color de la reserva",
        help_text="Hexadecimal, por ejemplo #32b8c6. Conviene usar el color principal del sitio. Vacío: el del tipo de negocio.",
        error_messages={"invalid": "Usa el formato #RRGGBB."},
    )
    faq_ocultas = forms.MultipleChoiceField(
        required=False, choices=PREGUNTAS, widget=forms.CheckboxSelectMultiple, label="Preguntas frecuentes ocultas"
    )

    class Meta:
        model = Consultorio
        exclude = ("contenido_sitio",)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        contenido = self.instance.contenido if self.instance.pk else CONTENIDO_POR_DEFECTO
        self.fields["formas_de_pago"].initial = ", ".join(contenido["formas_de_pago"])
        for campo in ("anos_practica", "publico", "referencias", "faq_ocultas", "color_acento"):
            self.fields[campo].initial = contenido[campo]
        for numero, bloque in enumerate(contenido["bloques_confianza"], start=1):
            self.fields[f"bloque_{numero}_titulo"].initial = bloque["titulo"]
            self.fields[f"bloque_{numero}_texto"].initial = bloque["texto"]

    def clean_foto(self):
        foto = self.cleaned_data.get("foto")
        # Solo una foto recién subida trae content_type; la ya guardada se deja tal cual.
        if foto and hasattr(foto, "content_type"):
            return ContentFile(a_webp(foto, lado_maximo=600).read(), name="doctor.webp")
        return foto

    def _imagen(self, campo: str, contenido: dict, slug: str) -> str:
        subida = self.cleaned_data.get(campo)
        if subida:
            return default_storage.save(f"consultorios/{slug}/{campo}.webp", a_webp(subida))
        return "" if self.cleaned_data.get(f"quitar_{campo}") else contenido[campo]

    def save(self, commit=True):
        anterior = self.instance.contenido
        datos = self.cleaned_data
        self.instance.contenido_sitio = {
            "logo": self._imagen("logo", anterior, datos.get("slug") or self.instance.slug),
            "foto_consultorio": self._imagen("foto_consultorio", anterior, datos.get("slug") or self.instance.slug),
            "formas_de_pago": [f.strip() for f in datos["formas_de_pago"].split(",") if f.strip()],
            "anos_practica": datos["anos_practica"],
            "publico": datos["publico"],
            "referencias": datos["referencias"],
            "bloques_confianza": [
                {"titulo": datos[f"bloque_{n}_titulo"], "texto": datos[f"bloque_{n}_texto"]} for n in (1, 2, 3)
            ],
            "faq_ocultas": datos["faq_ocultas"],
            "color_acento": (datos.get("color_acento") or "").lower(),
        }
        return super().save(commit)


@admin.register(Consultorio)
class ConsultorioAdmin(admin.ModelAdmin):
    """Alta de un consultorio (RF-33): datos del sitio, tratamientos y horario en una sola pantalla."""

    form = ConsultorioForm
    list_display = ("nombre", "slug", "doctor_nombre", "publicado", "activo")
    list_filter = ("publicado", "activo")
    search_fields = ("nombre", "slug")
    prepopulated_fields = {"slug": ("nombre",)}
    readonly_fields = ("metricas_30_dias",)
    inlines = [TratamientoInline, HorarioInline, BloqueoInline]
    fieldsets = (
        (None, {"fields": ("nombre", "slug", "publicado", "activo")}),
        ("Doctor", {"fields": ("doctor_nombre", "colegiatura", "foto", "presentacion", "anos_practica", "publico")}),
        ("Contacto", {"fields": ("direccion", "referencias", "mapa_url", "whatsapp")}),
        (
            "Contenido del sitio",
            {
                "fields": (
                    "logo",
                    "quitar_logo",
                    "foto_consultorio",
                    "quitar_foto_consultorio",
                    "formas_de_pago",
                    "bloque_1_titulo",
                    "bloque_1_texto",
                    "bloque_2_titulo",
                    "bloque_2_texto",
                    "bloque_3_titulo",
                    "bloque_3_texto",
                    "faq_ocultas",
                )
            },
        ),
        ("Reglas", {"fields": ("reglas",), "classes": ("collapse",)}),
        ("Medición", {"fields": ("metricas_30_dias",)}),
    )

    @admin.display(description="Últimos 30 días")
    def metricas_30_dias(self, consultorio):
        if not consultorio.pk:
            return "—"
        ahora = timezone.now()
        datos = resumen(consultorio, ahora - timedelta(days=30), ahora)
        return format_html_join(mark_safe("<br>"), "{}: {}", ((k, "sin datos" if v is None else v) for k, v in datos.items()))

    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        purgar_sitio(form.instance.slug)  # el horario se edita en la misma pantalla


class UsuarioCreacionForm(forms.ModelForm):
    password1 = forms.CharField(label="Contraseña", widget=forms.PasswordInput)

    class Meta:
        model = Usuario
        fields = ("correo", "consultorio")

    def save(self, commit=True):
        usuario = super().save(commit=False)
        usuario.correo = usuario.correo.lower()
        usuario.set_password(self.cleaned_data["password1"])
        if commit:
            usuario.save()
        return usuario


@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    """Sin correo en el MVP: las contraseñas se restablecen desde aquí."""

    add_form = UsuarioCreacionForm
    ordering = ("correo",)
    list_display = ("correo", "consultorio", "activo", "is_staff", "bloqueado_hasta")
    list_filter = ("activo", "is_staff", "consultorio")
    search_fields = ("correo",)
    filter_horizontal = ()
    fieldsets = (
        (None, {"fields": ("correo", "password", "consultorio", "activo")}),
        ("Seguridad", {"fields": ("intentos_fallidos", "bloqueado_hasta", "is_staff", "is_superuser")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("correo", "consultorio", "password1")}),)
