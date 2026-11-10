"""Verificación por WhatsApp (RF-09, RF-10, RF-13) y enlace de gestión (RF-12, RF-14 a RF-16)."""
import hashlib
import hmac
import json
from datetime import timedelta

import pytest

from citas.models import Cita, Estado, Paciente
from mensajeria.models import MensajeEntrante
from .conftest import AHORA, reservar

pytestmark = [pytest.mark.django_db, pytest.mark.verificacion_whatsapp]
SECRETO = "secreto-de-prueba"


def payload(texto, celular="51987654321", wamid="wamid.1", tipo="text"):
    mensaje = {"from": celular, "id": wamid, "timestamp": "1", "type": tipo}
    if tipo == "text":
        mensaje["text"] = {"body": texto}
    return {
        "object": "whatsapp_business_account",
        "entry": [{"id": "1", "changes": [{"field": "messages", "value": {"messaging_product": "whatsapp", "messages": [mensaje]}}]}],
    }


def enviar(cliente, cuerpo, firma=None):
    crudo = json.dumps(cuerpo).encode()
    firma = firma if firma is not None else "sha256=" + hmac.new(SECRETO.encode(), crudo, hashlib.sha256).hexdigest()
    return cliente.post(
        "/webhooks/whatsapp", crudo, content_type="application/json", headers={"x-hub-signature-256": firma}
    )


@pytest.fixture
def reserva(cliente, limpieza):
    return reservar(cliente, inicio=AHORA + timedelta(days=2, hours=2)).json()


def ver(cliente, reserva):
    return cliente.get(f"/public/v1/citas/{reserva['token']}").json()


def confirmar(cliente, reserva):
    return enviar(cliente, payload(f"Hola, código: {reserva['codigo']}"))


# --- Webhook ------------------------------------------------------------------------------


def test_meta_verifica_el_webhook(cliente):
    r = cliente.get(
        "/webhooks/whatsapp", {"hub.mode": "subscribe", "hub.verify_token": "token-de-prueba", "hub.challenge": "123"}
    )
    assert r.status_code == 200 and r.content == b"123"


def test_token_de_verificacion_incorrecto(cliente):
    r = cliente.get("/webhooks/whatsapp", {"hub.mode": "subscribe", "hub.verify_token": "x", "hub.challenge": "1"})
    assert r.status_code == 403


def test_firma_invalida_no_confirma(cliente, reserva):
    assert enviar(cliente, payload(reserva["codigo"]), firma="sha256=falsa").status_code == 403
    assert ver(cliente, reserva)["estado"] == Estado.PENDIENTE


def test_sin_firma_no_confirma(cliente, reserva):
    assert enviar(cliente, payload(reserva["codigo"]), firma="").status_code == 403
    assert not MensajeEntrante.objects.exists()


def test_codigo_y_numero_correctos_programan_la_cita(cliente, reserva):
    assert confirmar(cliente, reserva).status_code == 200
    assert ver(cliente, reserva)["estado"] == Estado.PROGRAMADA
    assert Paciente.objects.get().verificado_en is not None


def test_el_push_se_encola_al_confirmar(reserva, cliente, django_capture_on_commit_callbacks, sin_push_real):
    with django_capture_on_commit_callbacks(execute=True):
        confirmar(cliente, reserva)
    assert sin_push_real.call_count == 1
    argumentos = sin_push_real.call_args.args
    assert argumentos[0] == "mensajeria.push.enviar_a_consultorio"
    assert argumentos[2] == "Nueva cita"


def test_un_numero_distinto_no_confirma(cliente, reserva):
    assert enviar(cliente, payload(reserva["codigo"], celular="51911111111")).status_code == 200
    assert ver(cliente, reserva)["estado"] == Estado.PENDIENTE


def test_codigo_en_minusculas_tambien_vale(cliente, reserva):
    enviar(cliente, payload(reserva["codigo"].lower()))
    assert ver(cliente, reserva)["estado"] == Estado.PROGRAMADA


def test_codigo_inexistente_se_ignora(cliente, reserva):
    assert enviar(cliente, payload("Código: DC-ZZZZZ")).status_code == 200
    assert ver(cliente, reserva)["estado"] == Estado.PENDIENTE


def test_mensaje_sin_codigo_se_guarda_y_no_hace_nada(cliente, reserva):
    enviar(cliente, payload("hola, ¿atienden hoy?"))
    assert MensajeEntrante.objects.get().cita is None


def test_mensaje_que_no_es_texto_no_rompe(cliente, reserva):
    assert enviar(cliente, payload("", tipo="image")).status_code == 200


def test_avisos_de_estado_sin_mensajes_no_rompen(cliente):
    cuerpo = {"entry": [{"changes": [{"value": {"statuses": [{"id": "x"}]}}]}]}
    assert enviar(cliente, cuerpo).status_code == 200


def test_json_invalido(cliente):
    crudo = b"no-json"
    firma = "sha256=" + hmac.new(SECRETO.encode(), crudo, hashlib.sha256).hexdigest()
    r = cliente.post("/webhooks/whatsapp", crudo, content_type="application/json", headers={"x-hub-signature-256": firma})
    assert r.status_code == 400


def test_el_mismo_mensaje_dos_veces_se_procesa_una_vez(cliente, reserva):
    confirmar(cliente, reserva)
    confirmar(cliente, reserva)
    assert MensajeEntrante.objects.count() == 1
    assert Cita.objects.get().eventos.filter(valor_nuevo=Estado.PROGRAMADA).count() == 1


def test_mensaje_tardio_no_revive_una_prerreserva_vencida(cliente, reloj, reserva):
    reloj.avanzar(minutes=16)
    confirmar(cliente, reserva)
    assert ver(cliente, reserva)["estado"] == Estado.EXPIRADA


def test_verificar_actualiza_el_nombre_del_paciente(cliente, consultorio, limpieza):
    Paciente.objects.create(consultorio=consultorio, nombre="Viejo", celular="+51987654321")
    r = reservar(cliente, nombre="Nombre Nuevo", inicio=AHORA + timedelta(days=1, hours=2)).json()
    confirmar(cliente, r)
    assert Paciente.objects.get().nombre == "Nombre Nuevo"


# --- Alternativa sin WhatsApp (RF-13) -----------------------------------------------------


def test_sin_whatsapp_queda_por_aprobar_y_no_expira_a_los_15_min(cliente, reloj, reserva, django_capture_on_commit_callbacks, sin_push_real):
    with django_capture_on_commit_callbacks(execute=True):
        r = cliente.post(f"/public/v1/citas/{reserva['token']}/sin-whatsapp")
    assert r.json()["estado"] == Estado.POR_APROBAR
    assert sin_push_real.call_args.args[2] == "Reserva por aprobar"
    reloj.avanzar(minutes=30)
    from citas import servicios

    servicios.expirar_vencidas()
    assert ver(cliente, reserva)["estado"] == Estado.POR_APROBAR


def test_por_aprobar_sigue_ocupando_el_horario(cliente, reloj, reserva):
    cliente.post(f"/public/v1/citas/{reserva['token']}/sin-whatsapp")
    reloj.avanzar(minutes=30)
    inicio = AHORA + timedelta(days=2, hours=2)
    assert reservar(cliente, inicio=inicio, celular="987000000").status_code == 409


def test_sin_whatsapp_no_aplica_a_una_prerreserva_vencida(cliente, reloj, reserva):
    reloj.avanzar(minutes=16)
    assert cliente.post(f"/public/v1/citas/{reserva['token']}/sin-whatsapp").json()["estado"] == Estado.EXPIRADA


def test_por_aprobar_vence_cuando_pasa_su_hora(cliente, reloj, reserva):
    from citas import servicios

    cliente.post(f"/public/v1/citas/{reserva['token']}/sin-whatsapp")
    reloj.avanzar(days=3)
    servicios.expirar_vencidas()
    assert Cita.objects.get().estado == Estado.EXPIRADA


# --- Mi cita ---------------------------------------------------------------------------------


def test_ver_cita_no_expone_el_celular(cliente, reserva):
    respuesta = cliente.get(f"/public/v1/citas/{reserva['token']}")
    assert respuesta.status_code == 200
    assert "987654321" not in respuesta.content.decode()


def test_token_inventado(cliente):
    assert cliente.get("/public/v1/citas/inventado").status_code == 404


def test_el_enlace_vence_24_h_despues_de_la_cita(cliente, reloj, reserva):
    confirmar(cliente, reserva)
    cita = Cita.objects.get()
    reloj.ahora = cita.fin + timedelta(hours=24)
    assert cliente.get(f"/public/v1/citas/{reserva['token']}").status_code == 200
    reloj.avanzar(seconds=1)
    assert cliente.get(f"/public/v1/citas/{reserva['token']}").status_code == 410
    assert cliente.get(f"/cita/{reserva['token']}/", headers={"host": "sonrisa.denticita.test"}).status_code == 410


def test_codigo_y_enlace_de_whatsapp_solo_mientras_esta_pendiente(cliente, reserva):
    assert ver(cliente, reserva)["codigo"] == reserva["codigo"]
    confirmar(cliente, reserva)
    datos = ver(cliente, reserva)
    assert datos["codigo"] is None and datos["whatsapp_url"] is None


@pytest.mark.parametrize("ruta", ["cancelar", "reprogramar"])
def test_el_paciente_ya_no_cancela_ni_mueve_desde_su_enlace(cliente, reserva, ruta):
    """Solo el doctor cancela o mueve citas; el enlace del paciente es de solo lectura."""
    confirmar(cliente, reserva)
    r = cliente.post(f"/public/v1/citas/{reserva['token']}/{ruta}", {}, content_type="application/json")
    assert r.status_code in (404, 405)
    assert cliente.get(f"/public/v1/citas/{reserva['token']}/disponibilidad").status_code in (404, 405)
    assert Cita.objects.get().estado == Estado.PROGRAMADA


def test_calendario_solo_con_la_cita_confirmada(cliente, reserva):
    ruta = f"/public/v1/citas/{reserva['token']}/calendario.ics"
    assert cliente.get(ruta).status_code == 409
    confirmar(cliente, reserva)
    r = cliente.get(ruta)
    assert r.status_code == 200
    assert r["Content-Type"].startswith("text/calendar")
    contenido = r.content.decode()
    assert "TRIGGER:-PT24H" in contenido and "TRIGGER:-PT2H" in contenido
    assert "SEQUENCE:0" in contenido


def test_calendario_sube_la_secuencia_al_reprogramar(cliente, reserva, api):
    confirmar(cliente, reserva)
    cita = Cita.objects.get()
    r = api.post(f"/citas/{cita.pk}/reprogramar", {"inicio": (cita.inicio + timedelta(days=1)).isoformat()})
    assert r.status_code == 200
    assert "SEQUENCE:1" in cliente.get(f"/public/v1/citas/{reserva['token']}/calendario.ics").content.decode()
