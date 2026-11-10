from datetime import datetime, time, timedelta
from unittest import mock
from zoneinfo import ZoneInfo

import pytest
from django.test import Client

from agenda.models import HorarioSemanal, Tratamiento
from consultorios.autenticacion import emitir_acceso
from consultorios.models import Consultorio, Usuario

LIMA = ZoneInfo("America/Lima")
# Lunes a las 8:00 en Lima. El reloj está fijo para que ninguna prueba dependa de cuándo se ejecuta.
AHORA = datetime(2026, 11, 9, 8, 0, tzinfo=LIMA)


class Reloj:
    def __init__(self):
        self.ahora = AHORA

    def __call__(self):
        return self.ahora

    def avanzar(self, **delta):
        self.ahora += timedelta(**delta)


@pytest.fixture(autouse=True)
def reloj():
    r = Reloj()
    with mock.patch("django.utils.timezone.now", r):
        yield r


@pytest.fixture(autouse=True)
def turnstile_valido(request):
    """Cloudflare no se llama en las pruebas, salvo las que prueban justamente esa función."""
    if "real_turnstile" in request.keywords:
        yield None
        return
    with mock.patch("mensajeria.turnstile.exigir_token") as m:
        yield m


@pytest.fixture(autouse=True)
def modo_verificacion(request, settings):
    """Por defecto, el flujo sin API de WhatsApp. Las pruebas marcadas `verificacion_whatsapp` usan el de Meta."""
    settings.VERIFICACION_WHATSAPP = "verificacion_whatsapp" in request.keywords
    yield


@pytest.fixture(autouse=True)
def modo_adelantos(request, settings):
    """Los adelantos están apagados en la plataforma; las pruebas marcadas `pagos_adelantados` los encienden."""
    settings.PAGOS_ADELANTADOS = "pagos_adelantados" in request.keywords
    yield


@pytest.fixture(autouse=True)
def sin_push_real():
    with mock.patch("mensajeria.push.async_task") as m:
        yield m


def crear_consultorio(slug="sonrisa", nombre="Sonrisa", **extra):
    c = Consultorio.objects.create(
        slug=slug,
        nombre=nombre,
        doctor_nombre="Dra. Prueba",
        direccion="Jr. Prueba 1",
        whatsapp="51911111111",
        publicado=True,
        **extra,
    )
    for dia in range(6):  # lunes a sábado, 9 a 13
        HorarioSemanal.objects.create(consultorio=c, dia_semana=dia, hora_inicio=time(9), hora_fin=time(13))
    return c


@pytest.fixture
def consultorio(db):
    return crear_consultorio()


@pytest.fixture
def otro_consultorio(db):
    return crear_consultorio(slug="ajeno", nombre="Consultorio Ajeno")


@pytest.fixture
def limpieza(consultorio):
    return Tratamiento.objects.create(
        consultorio=consultorio,
        nombre="Limpieza",
        motivo_paciente="Quiero una limpieza",
        duracion_min=30,
        margen_min=10,
        precio_desde=80,
    )


@pytest.fixture
def doctor(consultorio):
    return Usuario.objects.create_user("doc@sonrisa.test", "clave-segura-123", consultorio=consultorio)


@pytest.fixture
def cliente():
    return Client(headers={"cf-connecting-ip": "200.1.1.1"})


class ApiDoctor:
    """Cliente con el token ya puesto: acorta las pruebas de la app."""

    def __init__(self, usuario):
        self.c = Client(headers={"authorization": f"Bearer {emitir_acceso(usuario)}"})

    def get(self, ruta, **params):
        return self.c.get(f"/api/v1{ruta}", params)

    def post(self, ruta, datos=None):
        return self.c.post(f"/api/v1{ruta}", datos or {}, content_type="application/json")

    def put(self, ruta, datos=None):
        return self.c.put(f"/api/v1{ruta}", datos or {}, content_type="application/json")

    def delete(self, ruta):
        return self.c.delete(f"/api/v1{ruta}")


@pytest.fixture
def api(doctor):
    return ApiDoctor(doctor)


def reservar(cliente, slug="sonrisa", motivo="limpieza", inicio=None, celular="+51987654321", nombre="Rosa Paz", **extra):
    inicio = inicio or AHORA.replace(hour=11)
    cuerpo = {
        "motivo": motivo,
        "inicio": inicio.isoformat(),
        "nombre": nombre,
        "celular": celular,
        "acepta_politica": True,
        **extra,
    }
    return cliente.post(f"/public/v1/{slug}/reservas", cuerpo, content_type="application/json")
