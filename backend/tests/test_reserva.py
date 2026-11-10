"""Reserva web y anti-abuso (RF-05 a RF-11, RF-17 a RF-19)."""
from datetime import timedelta
from unittest import mock
from zoneinfo import ZoneInfo

import pytest
import requests
from django.db import IntegrityError, transaction
from django.test import Client, override_settings

from agenda.models import Bloqueo, Tratamiento
from citas import servicios
from citas.models import Cita, Estado, EventoCita, Paciente
from denticita.errores import ErrorNegocio
from mensajeria import turnstile
from .conftest import AHORA, reservar

pytestmark = pytest.mark.django_db


def disponibilidad(cliente, motivo="limpieza", **params):
    return cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": motivo, **params})


def horas_del(respuesta, fecha):
    for d in respuesta.json()["dias"]:
        if d["fecha"] == fecha:
            return [h[11:16] for h in d["horas"]]
    return []


HOY = "2026-11-09"


def test_perfil_solo_muestra_tratamientos_visibles_y_motivos_reservables(cliente, consultorio, limpieza):
    Tratamiento.objects.create(consultorio=consultorio, nombre="Oculto", visible=False, reservable=False)
    Tratamiento.objects.create(consultorio=consultorio, nombre="Solo info", visible=True, reservable=False)
    datos = cliente.get("/public/v1/sonrisa/perfil").json()
    assert [t["nombre"] for t in datos["tratamientos"]] == ["Limpieza", "Solo info"]
    assert [t["nombre"] for t in datos["motivos"]] == ["Limpieza"]
    assert datos["horario"][0]["tramos"] == ["9:00 a. m. a 1:00 p. m."]
    assert datos["horario"][6]["tramos"] == []


def test_disponibilidad_respeta_anticipacion_y_horario(cliente, limpieza):
    horas = horas_del(disponibilidad(cliente), HOY)  # 8:00 + 2 h
    assert horas[0] == "10:00"
    assert horas[-1] == "12:30"


def test_tratamiento_no_reservable_no_tiene_disponibilidad(cliente, limpieza):
    limpieza.reservable = False
    limpieza.save()
    assert disponibilidad(cliente).status_code == 404


def test_cambio_de_horario_se_ve_al_instante(cliente, consultorio, limpieza):
    consultorio.horarios.all().delete()
    assert horas_del(disponibilidad(cliente), HOY) == []


def test_bloqueo_quita_las_horas(cliente, consultorio, limpieza):
    Bloqueo.objects.create(consultorio=consultorio, inicio=AHORA.replace(hour=10), fin=AHORA.replace(hour=13))
    assert horas_del(disponibilidad(cliente), HOY) == []


@pytest.mark.verificacion_whatsapp
def test_crear_prerreserva_retiene_15_min(cliente, limpieza):
    r = reservar(cliente)
    assert r.status_code == 201
    datos = r.json()
    assert datos["codigo"].startswith("DC-")
    assert "wa.me/51900000000" in datos["whatsapp_url"]
    assert datos["codigo"] in datos["whatsapp_url"]
    assert "Sonrisa" in datos["whatsapp_url"]
    cita = Cita.objects.get()
    assert cita.estado == Estado.PENDIENTE
    assert cita.expira_en == AHORA + timedelta(minutes=15)
    assert cita.fin_ocupado - cita.inicio == timedelta(minutes=40)  # 30 + margen 10
    assert "11:00" not in horas_del(disponibilidad(cliente), HOY)


@pytest.mark.parametrize("celular", ["987654321", "+51 987 654 321", "51987654321", "987-654-321"])
def test_acepta_formatos_de_celular_peruano(cliente, limpieza, celular):
    assert reservar(cliente, celular=celular).status_code == 201
    assert Paciente.objects.get().celular == "+51987654321"


@pytest.mark.parametrize("celular", ["", "12345", "887654321", "9876543210", "+1987654321", "98765432a"])
def test_rechaza_celular_invalido(cliente, limpieza, celular):
    r = reservar(cliente, celular=celular)
    assert r.status_code == 422
    assert r.json()["codigo"] == "celular_invalido"


def test_exige_consentimiento(cliente, limpieza):
    r = reservar(cliente, acepta_politica=False)
    assert r.status_code == 422
    assert r.json()["codigo"] == "sin_consentimiento"
    assert not Paciente.objects.exists()


def test_exige_nombre(cliente, limpieza):
    assert reservar(cliente, nombre=" ").json()["codigo"] == "nombre_invalido"


@pytest.mark.parametrize(
    "inicio",
    [
        AHORA.replace(hour=9),  # menos de 2 h de anticipación
        AHORA.replace(hour=14),  # fuera del horario
        AHORA.replace(hour=12, minute=45),  # no cabe antes del cierre
        AHORA.replace(hour=10, minute=7),  # fuera de la grilla
        AHORA + timedelta(days=30),  # más allá de los 30 días
        AHORA - timedelta(days=1),  # en el pasado
        AHORA + timedelta(days=6),  # domingo: cerrado
    ],
)
def test_el_servidor_no_acepta_horas_que_no_ofrecio(cliente, limpieza, inicio):
    r = reservar(cliente, inicio=inicio)
    assert r.status_code == 409
    assert r.json()["codigo"] == "horario_tomado"


def test_hora_sin_zona_horaria_se_rechaza(cliente, limpieza):
    r = cliente.post(
        "/public/v1/sonrisa/reservas",
        {"motivo": "limpieza", "inicio": "2026-11-09T11:00:00", "nombre": "Rosa", "celular": "987654321", "acepta_politica": True},
        content_type="application/json",
    )
    assert r.status_code == 422


def test_misma_hora_en_zona_utc_es_la_misma_cita(cliente, limpieza):
    assert reservar(cliente).status_code == 201
    desde_utc = AHORA.replace(hour=11).astimezone(ZoneInfo("UTC"))
    assert reservar(cliente, inicio=desde_utc, celular="987000000").status_code == 409


def test_segunda_reserva_a_la_misma_hora_recibe_horario_tomado(cliente, limpieza):
    assert reservar(cliente).status_code == 201
    r = reservar(cliente, celular="987000000")
    assert r.status_code == 409
    assert r.json()["detail"].startswith("Ese horario acaba de ocuparse")


def test_el_margen_protege_a_la_cita_anterior(cliente, limpieza):
    assert reservar(cliente, inicio=AHORA.replace(hour=11)).status_code == 201  # ocupa hasta 11:40
    assert reservar(cliente, inicio=AHORA.replace(hour=11, minute=30), celular="987000000").status_code == 409
    assert reservar(cliente, inicio=AHORA.replace(hour=11, minute=45), celular="987000000").status_code == 201


def test_la_base_impide_el_cruce_aunque_se_salte_el_servicio(limpieza, consultorio):
    """Última línea de defensa: sin pasar por el motor, la restricción igual lo rechaza."""
    paciente = Paciente.objects.create(consultorio=consultorio, nombre="A", celular="+51900000001")
    inicio = AHORA.replace(hour=10)
    base = dict(consultorio=consultorio, paciente=paciente, tratamiento=limpieza, inicio=inicio)
    fin = inicio + timedelta(minutes=30)
    Cita.objects.create(**base, fin=fin, fin_ocupado=fin, estado=Estado.PROGRAMADA, token_gestion="a")
    with pytest.raises(IntegrityError), transaction.atomic():
        Cita.objects.create(**base, fin=fin, fin_ocupado=fin, estado=Estado.PENDIENTE, token_gestion="b")
    # Una cita terminada o cancelada ya no ocupa el horario.
    Cita.objects.create(**base, fin=fin, fin_ocupado=fin, estado=Estado.CANCELADA, token_gestion="c")


def test_consultorios_distintos_pueden_tener_la_misma_hora(cliente, limpieza, otro_consultorio):
    Tratamiento.objects.create(consultorio=otro_consultorio, nombre="Limpieza", duracion_min=30)
    assert reservar(cliente).status_code == 201
    assert reservar(cliente, slug="ajeno").status_code == 201


@pytest.mark.verificacion_whatsapp
def test_prerreserva_vencida_libera_el_horario_aunque_la_tarea_no_haya_corrido(cliente, reloj, limpieza):
    assert reservar(cliente).status_code == 201
    reloj.avanzar(minutes=15)
    assert "11:00" in horas_del(disponibilidad(cliente), HOY)
    assert reservar(cliente, celular="987000000").status_code == 201
    assert Cita.objects.filter(estado=Estado.EXPIRADA).count() == 1


def test_prerreserva_no_vencida_sigue_reteniendo(cliente, reloj, limpieza):
    assert reservar(cliente).status_code == 201
    reloj.avanzar(minutes=14, seconds=59)
    assert "11:00" not in horas_del(disponibilidad(cliente), HOY)


def test_maximo_dos_citas_futuras_por_numero(cliente, limpieza):
    assert reservar(cliente, inicio=AHORA.replace(hour=10)).status_code == 201
    assert reservar(cliente, inicio=AHORA.replace(hour=11)).status_code == 201
    r = reservar(cliente, inicio=AHORA.replace(hour=12))
    assert r.status_code == 409
    assert r.json()["codigo"] == "limite_citas"
    assert "2 citas" in r.json()["detail"]


def test_el_limite_es_por_consultorio(cliente, limpieza, otro_consultorio):
    Tratamiento.objects.create(consultorio=otro_consultorio, nombre="Limpieza", duracion_min=30)
    reservar(cliente, inicio=AHORA.replace(hour=10))
    reservar(cliente, inicio=AHORA.replace(hour=11))
    assert reservar(cliente, slug="ajeno", inicio=AHORA.replace(hour=12)).status_code == 201


@pytest.mark.verificacion_whatsapp
def test_las_pre_reservas_vencidas_no_cuentan_para_el_limite(cliente, reloj, limpieza):
    reservar(cliente, inicio=AHORA.replace(hour=10))
    reservar(cliente, inicio=AHORA.replace(hour=11))
    reloj.avanzar(minutes=16)
    assert reservar(cliente, inicio=AHORA.replace(hour=12)).status_code == 201


def test_cinco_intentos_por_ip_por_hora_incluye_los_fallidos(cliente, reloj, limpieza):
    for _ in range(5):
        assert reservar(cliente, celular="123").status_code == 422
    r = reservar(cliente)
    assert r.status_code == 429
    assert r.json()["codigo"] == "demasiados_intentos"
    otra_ip = Client(headers={"cf-connecting-ip": "200.2.2.2"})
    assert reservar(otra_ip).status_code == 201
    reloj.avanzar(hours=1, seconds=1)
    assert reservar(cliente, inicio=AHORA.replace(hour=12), celular="987000000").status_code == 201


def test_la_ip_no_se_guarda_en_claro(cliente, limpieza):
    from citas.models import IntentoReserva

    reservar(cliente)
    assert "200.1.1.1" not in IntentoReserva.objects.get().ip_hash


@override_settings(CONFIAR_CLOUDFLARE=False)
def test_sin_cloudflare_no_se_confia_en_el_encabezado(limpieza):
    # Cambiar el encabezado en cada intento no evade el límite: cuenta la IP real de la conexión.
    for i in range(6):
        r = reservar(Client(REMOTE_ADDR="10.0.0.9", headers={"cf-connecting-ip": f"9.9.9.{i}"}), celular="123")
    assert r.status_code == 429


def test_numero_bloqueado_recibe_mensaje_generico(cliente, consultorio, limpieza):
    Paciente.objects.create(consultorio=consultorio, nombre="X", celular="+51987654321", bloqueado=True)
    r = reservar(cliente)
    assert r.status_code == 403
    assert "bloque" not in r.json()["detail"].lower()
    assert not Cita.objects.exists()


def test_el_nombre_sin_verificar_no_pisa_al_paciente_existente(cliente, consultorio, limpieza):
    Paciente.objects.create(consultorio=consultorio, nombre="Nombre Real", celular="+51987654321")
    assert reservar(cliente, nombre="Impostor").status_code == 201
    assert Paciente.objects.get().nombre == "Nombre Real"
    assert Cita.objects.get().nombre_ingresado == "Impostor"


def test_consultorio_inactivo_no_recibe_reservas(cliente, consultorio, limpieza):
    consultorio.activo = False
    consultorio.save()
    assert reservar(cliente).status_code == 404
    assert cliente.get("/public/v1/sonrisa/perfil").status_code == 404


@pytest.mark.verificacion_whatsapp
def test_toda_prerreserva_deja_auditoria(cliente, limpieza):
    reservar(cliente)
    evento = EventoCita.objects.get()
    assert evento.valor_nuevo == Estado.PENDIENTE and evento.usuario is None


def test_turnstile_se_llama_con_el_token_y_la_ip(cliente, limpieza, turnstile_valido):
    reservar(cliente, turnstile="abc")
    turnstile_valido.assert_called_once_with("abc", "200.1.1.1")


def test_turnstile_invalido_rechaza_sin_crear_nada(cliente, limpieza, turnstile_valido):
    turnstile_valido.side_effect = ErrorNegocio("verificacion_fallida", "No.", 403)
    assert reservar(cliente).status_code == 403
    assert not Cita.objects.exists()


@pytest.mark.real_turnstile
class TestVerificacionTurnstile:
    @override_settings(TURNSTILE_SECRET="s")
    def test_sin_token_rechaza_sin_llamar_a_cloudflare(self):
        with mock.patch("requests.post") as post, pytest.raises(ErrorNegocio):
            turnstile.exigir_token("", "1.1.1.1")
        post.assert_not_called()

    @override_settings(TURNSTILE_SECRET="s")
    def test_token_valido_pasa(self):
        with mock.patch("requests.post") as post:
            post.return_value.json.return_value = {"success": True}
            turnstile.exigir_token("t", "1.1.1.1")

    @override_settings(TURNSTILE_SECRET="s")
    def test_cloudflare_dice_que_no(self):
        with mock.patch("requests.post") as post, pytest.raises(ErrorNegocio):
            post.return_value.json.return_value = {"success": False}
            turnstile.exigir_token("t", "1.1.1.1")

    @override_settings(TURNSTILE_SECRET="s")
    def test_si_cloudflare_no_responde_falla_cerrado(self):
        with mock.patch("requests.post", side_effect=requests.ConnectionError), pytest.raises(ErrorNegocio):
            turnstile.exigir_token("t", "1.1.1.1")

    @override_settings(TURNSTILE_SECRET="", DEBUG=False)
    def test_produccion_sin_secreto_falla_cerrado(self):
        with pytest.raises(ErrorNegocio):
            turnstile.exigir_token("t", "1.1.1.1")


@pytest.mark.verificacion_whatsapp
def test_codigo_duplicado_se_reintenta(cliente, limpieza):
    reservar(cliente, inicio=AHORA.replace(hour=10))
    usado = Cita.objects.get().codigo
    with mock.patch.object(servicios, "_nuevo_codigo", side_effect=[usado, "DC-AAAAA"]):
        r = reservar(cliente, inicio=AHORA.replace(hour=11), celular="987000000")
    assert r.status_code == 201
    assert r.json()["codigo"] == "DC-AAAAA"
