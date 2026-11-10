"""Formularios del panel. Validan lo mismo que el modelo y traducen al formato de panel/negocios.py."""
from __future__ import annotations

from datetime import time

from django import forms
from django.conf import settings
from django.core.validators import RegexValidator

from agenda.models import Tratamiento
from consultorios.admin import ConsultorioForm
from consultorios.models import OPCIONES_POR_DEFECTO, Consultorio, Profesional, Usuario, validar_subdominio
from consultorios.rubros import RUBRO_CHOICES

DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
MODOS = [
    ("compartida", "Agenda compartida: una cita a la vez (varias cuentas pueden manejarla)"),
    ("por_profesional", "Un profesional por cuenta: cada uno con su agenda, atienden en paralelo"),
]
SESION_WEB = [(30, "30 minutos"), (60, "1 hora")]


class OpcionesForm(forms.Form):
    """Interruptores por negocio. «Adelantos» se muestra apagado: la plataforma aún no lo usa."""

    modo_agenda = forms.ChoiceField(label="Agenda", choices=MODOS, widget=forms.RadioSelect)
    elegir_profesional = forms.BooleanField(
        label="El cliente elige con quién (o «Cualquiera»)", required=False,
        help_text="Solo con un profesional por cuenta.",
    )
    precio_ofertable = forms.BooleanField(
        label="Precio ofertable (tipo InDrive)", required=False,
        help_text="El cliente puede ofrecer otro precio al reservar; el negocio acepta o pone el final al confirmar.",
    )
    llegar_antes_min = forms.IntegerField(label="Pedir que llegue antes (min)", min_value=0, max_value=60)
    tolerancia_inasistencia_min = forms.IntegerField(label="Tolerancia antes de «No vino» (min)", min_value=0, max_value=60)
    recordar_pendientes_horas = forms.IntegerField(
        label="Recordar reservas sin confirmar a las (horas)", min_value=1, max_value=48
    )
    recordar_cita_min = forms.TypedChoiceField(
        label="Avisar al profesional antes de cada cita", coerce=int, required=False, empty_value=30,
        choices=[(0, "No avisar"), (10, "10 min antes"), (15, "15 min antes"), (30, "30 min antes"),
                 (60, "1 hora antes")],
        help_text="Notificación en la app (Firebase) a quien atiende la cita.",
    )
    turnos = forms.CharField(
        label="Turnos de la agenda", max_length=120, required=False,
        help_text="Nombre y hora de fin, separados por comas. El último llega al final del día. "
                  "Ejemplo: «Mañana 13:00, Tarde». Vacío: Mañana hasta las 13:00 y Tarde.",
    )
    sesion_web_min = forms.TypedChoiceField(label="El sitio recuerda los datos del cliente", choices=SESION_WEB, coerce=int)
    anticipacion_min_horas = forms.IntegerField(label="Anticipación mínima para reservar (horas)", min_value=0, max_value=72)
    dias_maximos = forms.IntegerField(label="Se puede reservar hasta (días)", min_value=1, max_value=120)
    adelantos = forms.BooleanField(
        label="Adelantos (Yape, Plin, efectivo)", required=False, disabled=True,
        help_text="Próximamente: desarrollado, pero deshabilitado en la plataforma.",
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if settings.PAGOS_ADELANTADOS:  # el interruptor de la plataforma habilita la casilla
            campo = self.fields["adelantos"]
            campo.disabled = False
            campo.help_text = "El encargado registra y verifica cada pago en la app."

    @classmethod
    def para(cls, consultorio: Consultorio | None = None, rubro: str | None = None, data=None):
        if consultorio is not None:
            iniciales = {**consultorio.opciones_efectivas, **consultorio.reglas_efectivas}
        else:
            from consultorios.models import REGLAS_POR_DEFECTO
            from consultorios.rubros import rubro as datos_rubro

            iniciales = {**OPCIONES_POR_DEFECTO, **REGLAS_POR_DEFECTO,
                         "llegar_antes_min": datos_rubro(rubro)["llegar_antes_min"]}
        iniciales["turnos"] = ", ".join(
            t["nombre"] if i == len(iniciales["turnos"]) - 1 else f'{t["nombre"]} {t["hasta"]}'
            for i, t in enumerate(iniciales["turnos"])
        )
        return cls(data, initial=iniciales)

    def clean_turnos(self):
        from consultorios.models import validar_turnos

        if not self.cleaned_data.get("turnos", "").strip():
            return OPCIONES_POR_DEFECTO["turnos"]
        turnos = []
        for parte in [p.strip() for p in self.cleaned_data["turnos"].split(",") if p.strip()]:
            nombre, _, hora = parte.rpartition(" ")
            if ":" not in hora:
                nombre, hora = parte, ""
            turnos.append({"nombre": nombre.strip(), "hasta": hora})
        try:
            return validar_turnos(turnos)
        except ValueError as error:
            raise forms.ValidationError(str(error)) from None

    def opciones(self) -> dict:
        d = self.cleaned_data
        claves = ["modo_agenda", "elegir_profesional", "precio_ofertable", "llegar_antes_min",
                  "tolerancia_inasistencia_min", "recordar_pendientes_horas", "sesion_web_min", "turnos",
                  "recordar_cita_min"]
        if settings.PAGOS_ADELANTADOS:
            claves.append("adelantos")
        return {c: d[c] for c in claves}

    def reglas(self) -> dict:
        return {"anticipacion_min_horas": self.cleaned_data["anticipacion_min_horas"],
                "dias_maximos": self.cleaned_data["dias_maximos"]}


class DatosNegocioForm(forms.Form):
    nombre = forms.CharField(max_length=120)
    slug = forms.SlugField(
        label="Subdominio", max_length=40,
        validators=[RegexValidator(r"^[a-z0-9]+(-[a-z0-9]+)*$", "Solo minúsculas, números y guiones."), validar_subdominio],
        help_text="La web queda en subdominio.plataforma.",
    )
    whatsapp = forms.CharField(
        label="WhatsApp del negocio", max_length=12,
        validators=[RegexValidator(r"^51\d{9}$", "Usa el formato 51987654321.")],
    )
    direccion = forms.CharField(label="Dirección", max_length=200)
    mapa_url = forms.URLField(label="Enlace de Google Maps", required=False)
    profesionales = forms.CharField(
        label="Quién atiende (uno por línea)", widget=forms.Textarea(attrs={"rows": 3}),
        help_text="Con agenda compartida basta uno: el dueño o el doctor.",
    )

    def clean_slug(self):
        slug = self.cleaned_data["slug"]
        if Consultorio.objects.filter(slug=slug).exists():
            raise forms.ValidationError("Ese subdominio ya está en uso.")
        return slug

    def lista_profesionales(self) -> list[str]:
        return [p.strip() for p in self.cleaned_data["profesionales"].splitlines() if p.strip()]


class ServicioForm(forms.Form):
    incluir = forms.BooleanField(required=False, initial=True)
    nombre = forms.CharField(max_length=80, required=False)
    motivo = forms.CharField(max_length=80, required=False)
    duracion_min = forms.IntegerField(min_value=5, max_value=600, required=False)
    margen_min = forms.IntegerField(min_value=0, max_value=120, required=False, initial=0)
    precio = forms.DecimalField(min_value=0, max_digits=8, decimal_places=2, required=False)
    indicaciones = forms.CharField(max_length=200, required=False)

    def clean(self):
        datos = super().clean()
        if datos.get("incluir") and datos.get("nombre"):
            if not datos.get("duracion_min"):
                self.add_error("duracion_min", "Indica la duración.")
        return datos


ServiciosFormSet = forms.formset_factory(ServicioForm, extra=2)


class HorarioForm(forms.Form):
    """Dos tramos por día (mañana y tarde). Vacío = cerrado."""

    def __init__(self, *args, tramos: list[tuple[int, time, time]] | None = None, **kwargs):
        super().__init__(*args, **kwargs)
        por_dia: dict[int, list[tuple[time, time]]] = {}
        for d, i, f in tramos or []:
            por_dia.setdefault(d, []).append((i, f))
        for d, nombre in enumerate(DIAS):
            for n in (1, 2):
                previo = por_dia.get(d, [])
                inicial = previo[n - 1] if len(previo) >= n else (None, None)
                self.fields[f"d{d}_i{n}"] = forms.TimeField(required=False, label=f"{nombre} desde", initial=inicial[0],
                                                            widget=forms.TimeInput(attrs={"type": "time"}, format="%H:%M"))
                self.fields[f"d{d}_f{n}"] = forms.TimeField(required=False, label="hasta", initial=inicial[1],
                                                            widget=forms.TimeInput(attrs={"type": "time"}, format="%H:%M"))

    def dias(self):
        """Filas para la plantilla: (nombre, [(desde, hasta), (desde, hasta)])."""
        return [
            (nombre, [(self[f"d{d}_i{n}"], self[f"d{d}_f{n}"]) for n in (1, 2)]) for d, nombre in enumerate(DIAS)
        ]

    def clean(self):
        datos = super().clean()
        for d, nombre in enumerate(DIAS):
            for n in (1, 2):
                i, f = datos.get(f"d{d}_i{n}"), datos.get(f"d{d}_f{n}")
                if (i is None) != (f is None):
                    self.add_error(f"d{d}_i{n}", f"{nombre}: completa desde y hasta.")
                elif i is not None and i >= f:
                    self.add_error(f"d{d}_i{n}", f"{nombre}: la hora de inicio debe ser antes del fin.")
        return datos

    def tramos(self) -> list[tuple[int, time, time]]:
        filas = []
        for d in range(7):
            for n in (1, 2):
                i, f = self.cleaned_data.get(f"d{d}_i{n}"), self.cleaned_data.get(f"d{d}_f{n}")
                if i is not None and f is not None:
                    filas.append((d, i, f))
        return filas


class SitioForm(ConsultorioForm):
    """Textos y fotos del sitio; los mismos campos del admin, sin los técnicos."""

    sitio_propio = forms.ChoiceField(
        required=False, label="Sitio web",
        help_text="Un sitio propio es el sitio completo del negocio (sitios_propios/); su botón «Agendar» abre RyCitas.",
    )

    def __init__(self, *args, **kwargs):
        from sitio import propios

        super().__init__(*args, **kwargs)
        opciones = [("", "Landing de RyCitas")] + [(n, f"Sitio propio: {n}") for n in propios.disponibles()]
        actual = self.instance.sitio_propio if self.instance.pk else ""
        if actual and actual not in dict(opciones):
            opciones.append((actual, f"Sitio propio: {actual} (no está compilado)"))
        self.fields["sitio_propio"].choices = opciones

    class Meta(ConsultorioForm.Meta):
        exclude = ("contenido_sitio", "slug", "reglas", "opciones", "rubro", "publicado", "activo", "suspendido",
                   "servicio_hasta")
        labels = {"doctor_nombre": "Nombre del responsable"}


class TratamientoForm(forms.ModelForm):
    class Meta:
        model = Tratamiento
        fields = ("nombre", "motivo_paciente", "duracion_min", "margen_min", "precio_desde", "indicaciones",
                  "reservable", "visible", "orden")


TratamientosFormSet = forms.inlineformset_factory(
    Consultorio, Tratamiento, form=TratamientoForm, extra=1, can_delete=False
)


class ProfesionalForm(forms.ModelForm):
    class Meta:
        model = Profesional
        fields = ("nombre", "detalle", "activo", "orden", "servicios")
        widgets = {"servicios": forms.CheckboxSelectMultiple}
        help_texts = {"servicios": "Sin marcar ninguno: hace todos los servicios."}


class _ProfesionalesBase(forms.BaseInlineFormSet):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for form in self.forms:  # solo los servicios de este negocio
            form.fields["servicios"].queryset = Tratamiento.objects.filter(consultorio=self.instance)


ProfesionalesFormSet = forms.inlineformset_factory(
    Consultorio, Profesional, form=ProfesionalForm, formset=_ProfesionalesBase, extra=1, can_delete=False
)


class CuentaForm(forms.Form):
    correo = forms.EmailField()
    nombre = forms.CharField(max_length=120, required=False)
    profesional = forms.ModelChoiceField(
        queryset=Profesional.objects.none(), required=False, empty_label="Encargado o recepción: ve toda la agenda"
    )

    def __init__(self, *args, consultorio: Consultorio, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["profesional"].queryset = consultorio.profesionales.filter(activo=True)

    def clean_correo(self):
        correo = self.cleaned_data["correo"].strip().lower()
        if Usuario.objects.filter(correo=correo).exists():
            raise forms.ValidationError("Ya existe una cuenta con ese correo.")
        return correo


class ServicioPagadoForm(forms.Form):
    servicio_hasta = forms.DateField(
        label="Servicio pagado hasta", required=False, widget=forms.DateInput(attrs={"type": "date"}, format="%Y-%m-%d")
    )
