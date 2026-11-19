"""El negocio reserva a un cliente que tiene la app, el cliente cancela o mueve su cita, seguir negocios y promociones,
y por qué hoy no hay horas (el problema de «después de las 12 ya no puedo reservar en la tarde»)."""
from datetime import time, timedelta
from unittest import mock

import pytest

from agenda.models import HorarioSemanal
from citas.models import Cita, Estado, Paciente
from clientes.models import Cupon, DispositivoCliente, Seguimiento
from .conftest import AHORA, ApiDoctor, reservar
from .test_clientes import ApiCliente, _cuenta

pytestmark = pytest.mark.django_db


@pytest.fixture
def tareas():
    with mock.patch("clientes.avisos.async_task") as m:
        yield m


def _titulos(tareas):
    return [c.args[2] for c in tareas.call_args_list if c.args[0] == "clientes.avisos.enviar"]


def _agendar(api, limpieza, hora=11, vincular=True, celular="987654321", dias=0):
    return api.post(
        "/citas",
        {
            "tratamiento_id": limpieza.pk,
            "inicio": (AHORA + timedelta(days=dias)).replace(hour=hora).isoformat(),
            "nombre": "Andre Mendez",
            "celular": celular,
            "vincular_app": vincular,
        },
    )


# --- El negocio reserva a quien tiene la app ---------------------------------------------------------------


def test_el_negocio_pregunta_si_el_numero_tiene_la_app(api, consultorio):
    _cuenta(nombre="Andre Mendez", verificado=False)
    assert api.get("/clientes-app", celular="987 654 321").json() == {"tiene_app": True, "nombre": "Andre Mendez"}
    assert api.get("/clientes-app", celular="911222333").json() == {"tiene_app": False}
    assert api.get("/clientes-app", celular="123").json() == {"tiene_app": False}


def test_al_vincular_la_cita_aparece_en_su_app_y_le_llega_el_aviso(
    api, limpieza, tareas, django_capture_on_commit_callbacks
):
    cuenta = _cuenta(nombre="Andre Mendez", verificado=False)
    with django_capture_on_commit_callbacks(execute=True):
        r = _agendar(api, limpieza)
    assert r.status_code == 201, r.content
    assert r.json()["en_su_app"] is True and "wa.me" in r.json()["whatsapp_url"]
    app = ApiCliente(cuenta)
    proximas = app.get("/mis-citas").json()["proximas"]
    assert len(proximas) == 1 and proximas[0]["estado"] == "programada"
    cuenta.refresh_from_db()
    assert cuenta.celular_verificado_en is not None  # el negocio dio fe: ya ve todo lo de su número
    assert any("te reservó una cita" in t for t in _titulos(tareas))


def test_sin_vincular_la_cita_no_aparece(api, limpieza):
    cuenta = _cuenta(verificado=False)
    assert _agendar(api, limpieza, vincular=False).json()["en_su_app"] is False
    assert ApiCliente(cuenta).get("/mis-citas").json()["proximas"] == []


def test_con_dos_cuentas_del_mismo_numero_no_se_adivina(api, limpieza):
    _cuenta(verificado=False)
    _cuenta(correo="otra@correo.pe", verificado=False)
    assert api.get("/clientes-app", celular="987654321").json() == {"tiene_app": False}
    assert _agendar(api, limpieza).json()["en_su_app"] is False


def test_vincular_una_cita_que_ya_existia(api, limpieza, tareas):
    cita_id = _agendar(api, limpieza, vincular=False).json()["cita_id"]
    cuenta = _cuenta(verificado=False)
    r = api.post(f"/citas/{cita_id}/vincular-app")
    assert r.status_code == 200, r.content
    assert Cita.objects.get(pk=cita_id).cliente_id == cuenta.pk
    assert len(ApiCliente(cuenta).get("/mis-citas").json()["proximas"]) == 1


def test_vincular_sin_cuenta_responde_404(api, limpieza):
    cita_id = _agendar(api, limpieza, vincular=False).json()["cita_id"]
    assert api.post(f"/citas/{cita_id}/vincular-app").status_code == 404


def test_cancelar_una_cita_vinculada_le_avisa_aunque_no_haya_probado_su_whatsapp(
    api, limpieza, tareas, django_capture_on_commit_callbacks
):
    _cuenta(verificado=False)
    cita_id = _agendar(api, limpieza, hora=12).json()["cita_id"]
    with django_capture_on_commit_callbacks(execute=True):
        assert api.post(f"/citas/{cita_id}/cancelar").status_code == 200
    llamada = [c for c in tareas.call_args_list if c.args[2] == "Tu cita fue cancelada"][0]
    assert llamada.args[8] is not None  # cuenta_id: le llega a la cuenta vinculada


# --- El cliente cancela o mueve desde su app -----------------------------------------------------------------


def _cita_del_cliente(api, limpieza, dias=1, hora=11):
    cuenta = _cuenta()
    cita_id = _agendar(api, limpieza, hora=hora, dias=dias).json()["cita_id"]
    return ApiCliente(cuenta), cita_id


def test_el_cliente_ve_hasta_cuando_puede_cambiarla(api, limpieza):
    app, cita_id = _cita_del_cliente(api, limpieza)
    cita = app.get("/mis-citas").json()["proximas"][0]
    assert cita["puede_cambiar"] is True
    assert cita["cambia_hasta"].startswith((AHORA + timedelta(days=1)).date().isoformat() + "T07:00")


def test_el_cliente_cancela_dentro_del_plazo_y_el_negocio_se_entera(api, limpieza, sin_push_real):
    app, cita_id = _cita_del_cliente(api, limpieza)
    r = app.post(f"/mis-citas/{cita_id}/cancelar")
    assert r.status_code == 200, r.content
    assert Cita.objects.get(pk=cita_id).estado == Estado.CANCELADA
    assert Cita.objects.get(pk=cita_id).eventos.filter(tipo="cancelada_por", valor_nuevo="cliente").exists()


def test_fuera_de_plazo_no_cancela_y_ofrece_whatsapp(api, limpieza, reloj):
    app, cita_id = _cita_del_cliente(api, limpieza, dias=0, hora=11)  # a las 8:00, faltan 3 h y el plazo es 4 h
    r = app.post(f"/mis-citas/{cita_id}/cancelar")
    assert r.status_code == 409 and r.json()["codigo"] == "fuera_de_plazo"
    assert "wa.me/51911111111" in r.json()["whatsapp_url"]
    assert app.get("/mis-citas").json()["proximas"][0]["puede_cambiar"] is False


def test_el_plazo_lo_elige_el_negocio(api, limpieza):
    assert api.put("/reglas", {"limite_cancelacion_horas": 2}).json()["limite_cancelacion_horas"] == 2
    app, cita_id = _cita_del_cliente(api, limpieza, dias=0, hora=11)
    assert app.post(f"/mis-citas/{cita_id}/cancelar").status_code == 200


def test_no_cancela_la_cita_de_otra_persona(api, limpieza):
    _, cita_id = _cita_del_cliente(api, limpieza)
    intrusa = ApiCliente(_cuenta(correo="intrusa@correo.pe", celular="+51911222333"))
    assert intrusa.post(f"/mis-citas/{cita_id}/cancelar").status_code == 404


def test_al_mover_queda_por_confirmar_y_el_negocio_la_revisa(api, limpieza):
    app, cita_id = _cita_del_cliente(api, limpieza)
    manana = (AHORA + timedelta(days=1)).replace(hour=12)
    r = app.post(f"/mis-citas/{cita_id}/reprogramar", {"inicio": manana.isoformat()})
    assert r.status_code == 200, r.content
    cita = Cita.objects.get(pk=cita_id)
    assert cita.estado == Estado.POR_APROBAR and cita.inicio == manana
    assert api.get("/citas/por-aprobar").json()["citas"][0]["id"] == cita_id


def test_no_se_mueve_a_una_hora_ocupada(api, limpieza):
    app, cita_id = _cita_del_cliente(api, limpieza)
    _agendar(api, limpieza, hora=12, dias=1, vincular=False, celular="911222333")
    manana = (AHORA + timedelta(days=1)).replace(hour=12)
    r = app.post(f"/mis-citas/{cita_id}/reprogramar", {"inicio": manana.isoformat()})
    assert r.status_code == 409 and r.json()["codigo"] == "horario_tomado"
    assert Cita.objects.get(pk=cita_id).estado == Estado.PROGRAMADA


# --- Seguir y promociones --------------------------------------------------------------------------------


def test_seguir_con_promociones_recibe_las_campanas_y_los_cupones_para_todos(api, consultorio, limpieza, tareas):
    cuenta = _cuenta(celular="+51955444333", verificado=False)
    DispositivoCliente.objects.create(cliente=cuenta, token_fcm="tok-1")
    app = ApiCliente(cuenta)
    assert app.get("/negocios/sonrisa").json()["preguntar_promos"] is True
    assert app.post("/negocios/sonrisa/seguir", {"seguir": True, "promos": True}).json() == {
        "siguiendo": True, "promos": True,
    }
    Cupon.objects.create(consultorio=consultorio, codigo="HOLA10", titulo="10 % en tu limpieza",
                         descuento_pct=10, vence_el=AHORA.date() + timedelta(days=10))
    assert [c["codigo"] for c in app.get("/beneficios").json()["cupones"]] == ["HOLA10"]
    assert api.get("/campanas/previa").json()["con_app"] == 1


def test_seguir_sin_promociones_no_recibe_campanas(api, consultorio):
    cuenta = _cuenta(celular="+51955444333", verificado=False)
    DispositivoCliente.objects.create(cliente=cuenta, token_fcm="tok-1")
    ApiCliente(cuenta).post("/negocios/sonrisa/seguir", {"seguir": True, "promos": False})
    assert Seguimiento.objects.get().promos is False
    assert api.get("/campanas/previa").json()["con_app"] == 0


def test_la_reserva_desde_la_app_pregunta_por_promociones_solo_la_primera_vez(consultorio, limpieza):
    app = ApiCliente(_cuenta())
    horas = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"][0]["horas"]
    r = app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": horas[0]})
    assert r.json()["preguntar_promos"] is True
    app.post("/negocios/sonrisa/seguir", {"seguir": True, "promos": True})
    r = app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": horas[4]})
    assert r.json()["preguntar_promos"] is False


# --- Por qué hoy no hay horas ------------------------------------------------------------------------------


@pytest.fixture
def con_tarde(consultorio):
    """Horario partido como el de GlowClinic: 9 a 13 y 15 a 18."""
    for dia in range(6):
        HorarioSemanal.objects.create(consultorio=consultorio, dia_semana=dia, hora_inicio=time(15), hora_fin=time(18))
    return consultorio


def _hoy(cliente):
    r = cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"}).json()
    dias = {d["fecha"]: d["horas"] for d in r["dias"]}
    return dias.get(AHORA.date().isoformat(), []), r["motivo_hoy"]


def test_a_las_12_30_se_reserva_la_tarde_del_mismo_dia(cliente, limpieza, con_tarde, reloj):
    reloj.avanzar(hours=4, minutes=30)
    horas, motivo = _hoy(cliente)
    assert horas and "T15:00:00" in horas[0] and motivo is None


def test_a_las_16_30_quedan_horas_con_la_anticipacion_de_1_hora(cliente, limpieza, con_tarde, reloj):
    reloj.avanzar(hours=8, minutes=30)
    horas, _ = _hoy(cliente)
    assert horas and "T17:30:00" in horas[0]


def test_sin_horas_por_anticipacion_lo_explica(cliente, consultorio, limpieza, con_tarde, reloj):
    consultorio.reglas = {"anticipacion_min_horas": 2}
    consultorio.save()
    reloj.avanzar(hours=8, minutes=30)  # 16:30 + 2 h = 18:30, después del cierre
    horas, motivo = _hoy(cliente)
    assert horas == [] and motivo == "anticipacion"


def test_ya_cerro_o_esta_lleno(cliente, limpieza, con_tarde, reloj):
    reloj.avanzar(hours=11)  # 19:00
    assert _hoy(cliente)[1] == "cerrado"


def test_la_app_del_negocio_ve_los_huecos_de_la_tarde_en_horas_redondas(api, limpieza, con_tarde, reloj):
    reloj.avanzar(hours=4, minutes=7, seconds=33)  # 12:07:33
    huecos = api.get("/agenda", fecha=AHORA.date().isoformat()).json()["huecos"]
    assert "T12:15:00" in huecos[0]["inicio"]
    assert any("T15:00:00" in h["inicio"] for h in huecos)


def test_por_profesional_y_todos_tambien_muestra_huecos(consultorio, doctor, limpieza, con_tarde):
    consultorio.opciones = {"modo_agenda": "por_profesional"}
    consultorio.save()
    huecos = ApiDoctor(doctor).get("/agenda", fecha=AHORA.date().isoformat(), profesional=0).json()["huecos"]
    assert huecos


def test_reglas_solo_entre_0_y_72(api):
    assert api.put("/reglas", {"anticipacion_min_horas": 99}).status_code == 422
    assert api.put("/reglas", {"anticipacion_min_horas": 0}).json()["anticipacion_min_horas"] == 0
