"""Notas de la reserva («corte en capas, traigo foto») y avisos push al cliente sobre sus citas."""
from datetime import date, timedelta
from unittest import mock

import pytest

from citas.models import Cita, Estado
from clientes import avisos
from clientes.models import DispositivoCliente
from .conftest import AHORA, reservar
from .test_clientes import ApiCliente, _cuenta

pytestmark = pytest.mark.django_db


@pytest.fixture
def tareas():
    with mock.patch("clientes.avisos.async_task") as m:
        yield m


def _envios(tareas):
    """(titulo, datos, solo_verificados, canal) de cada push al cliente encolado."""
    return [
        (c.args[2], c.args[4], c.args[6], c.args[7]) for c in tareas.call_args_list if c.args[0] == "clientes.avisos.enviar"
    ]


# --- Notas -----------------------------------------------------------------------------------------------


def test_la_reserva_web_guarda_las_notas_limpias_y_el_negocio_las_ve(cliente, limpieza, api):
    r = reservar(cliente, notas="  Corte en capas <b>traigo foto</b>\x07  ")
    assert r.status_code == 201, r.content
    cita = Cita.objects.get(token_gestion=r.json()["token"])
    assert cita.notas == "Corte en capas traigo foto"
    agenda = api.get("/agenda", fecha=AHORA.date().isoformat()).json()
    assert agenda["citas"][0]["notas"] == "Corte en capas traigo foto"


def test_las_notas_se_recortan_a_500(cliente, limpieza):
    r = reservar(cliente, notas="x" * 900)
    assert len(Cita.objects.get(token_gestion=r.json()["token"]).notas) == 500


def test_reserva_desde_la_app_con_notas_y_el_cliente_las_ve(consultorio, limpieza):
    app = ApiCliente(_cuenta())
    hora = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"][0]["horas"][0]
    r = app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": hora, "notas": "Piel sensible"})
    assert r.status_code == 201, r.content
    assert app.get("/mis-citas").json()["proximas"][0]["notas"] == "Piel sensible"


def test_lo_reservado_desde_la_app_se_ve_aunque_el_whatsapp_no_este_probado(consultorio, limpieza, cliente):
    reservar(cliente)  # una cita de ese número hecha en la web: esa todavía no se muestra
    app = ApiCliente(_cuenta(verificado=False))
    hora = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"][0]["horas"][1]
    r = app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": hora})
    assert r.status_code == 201, r.content
    proximas = app.get("/mis-citas").json()["proximas"]
    assert len(proximas) == 1 and proximas[0]["estado"] == "por_aprobar"


def test_otra_cuenta_con_el_mismo_numero_no_ve_lo_que_reservo_la_primera(consultorio, limpieza):
    app = ApiCliente(_cuenta(verificado=False))
    hora = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"][0]["horas"][0]
    assert app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": hora}).status_code == 201
    intrusa = ApiCliente(_cuenta(correo="intrusa@correo.pe", verificado=False))
    assert intrusa.get("/mis-citas").json()["proximas"] == []


def test_el_negocio_agenda_con_notas_y_luego_las_edita(limpieza, api):
    r = api.post("/citas", {
        "tratamiento_id": limpieza.pk, "inicio": AHORA.replace(hour=11).isoformat(),
        "nombre": "Rosa Paz", "celular": "987654321", "notas": "Quiere degradado",
    })
    assert r.status_code == 201, r.content
    cita_id = r.json()["cita_id"]
    assert Cita.objects.get(pk=cita_id).notas == "Quiere degradado"
    r = api.put(f"/citas/{cita_id}/notas", {"notas": "Degradado bajo y barba"})
    assert r.status_code == 200 and r.json()["notas"] == "Degradado bajo y barba"
    # El texto no se copia al historial de la cita.
    assert not Cita.objects.get(pk=cita_id).eventos.filter(valor_nuevo__icontains="barba").exists()


def test_las_notas_de_otro_negocio_no_se_editan(limpieza, api, otro_consultorio):
    from agenda.models import Tratamiento
    from consultorios.models import Usuario
    from .conftest import ApiDoctor

    t = Tratamiento.objects.create(consultorio=otro_consultorio, nombre="Corte", slug="corte", duracion_min=30)
    otro = ApiDoctor(Usuario.objects.create_user("otro@x.test", "clave-segura-123", consultorio=otro_consultorio))
    r = otro.post("/citas", {
        "tratamiento_id": t.pk, "inicio": AHORA.replace(hour=11).isoformat(), "nombre": "Ana", "celular": "987000111",
    })
    assert r.status_code == 201, r.content
    assert api.put(f"/citas/{r.json()['cita_id']}/notas", {"notas": "hola"}).status_code == 404


# --- Avisos al cliente -------------------------------------------------------------------------------------


def _por_confirmar(cliente) -> Cita:
    r = reservar(cliente, notas="Dato privado")
    return Cita.objects.get(token_gestion=r.json()["token"])


def test_confirmar_avisa_al_cliente_sin_el_servicio_ni_las_notas(
    cliente, limpieza, api, tareas, django_capture_on_commit_callbacks
):
    cita = _por_confirmar(cliente)
    with django_capture_on_commit_callbacks(execute=True):
        assert api.post(f"/citas/{cita.pk}/aprobar").status_code == 200
    [(titulo, datos, solo_verificados, canal)] = _envios(tareas)
    assert "confirmada" in titulo
    assert datos == {"tipo": "cita", "cita_id": cita.pk, "negocio": "sonrisa"}
    assert solo_verificados is True and canal == avisos.CANAL_CITAS
    cuerpo = tareas.call_args.args[3]
    assert "Dato privado" not in cuerpo and limpieza.nombre not in cuerpo


@pytest.mark.parametrize(
    ("accion", "palabra"),
    [("rechazar", "No pudieron"), ("cancelar", "cancelada")],
)
def test_rechazar_o_cancelar_avisan_al_cliente(cliente, limpieza, api, tareas, django_capture_on_commit_callbacks, accion, palabra):
    cita = _por_confirmar(cliente)
    with django_capture_on_commit_callbacks(execute=True):
        assert api.post(f"/citas/{cita.pk}/{accion}").status_code == 200
    [(titulo, *_)] = _envios(tareas)
    assert palabra in titulo


def test_mover_la_cita_avisa_y_rearma_los_recordatorios(cliente, limpieza, api, tareas, django_capture_on_commit_callbacks):
    cita = _por_confirmar(cliente)
    Cita.objects.filter(pk=cita.pk).update(aviso_cliente_24h_en=AHORA)
    with django_capture_on_commit_callbacks(execute=True):
        r = api.post(f"/citas/{cita.pk}/reprogramar", {"inicio": AHORA.replace(hour=12).isoformat()})
    assert r.status_code == 200, r.content
    [(titulo, *_)] = _envios(tareas)
    assert "cambió" in titulo
    assert Cita.objects.get(pk=cita.pk).aviso_cliente_24h_en is None


def test_si_la_accion_falla_no_sale_el_aviso(cliente, limpieza, api, tareas, django_capture_on_commit_callbacks):
    cita = _por_confirmar(cliente)
    with django_capture_on_commit_callbacks(execute=True):
        api.post(f"/citas/{cita.pk}/aprobar")
    tareas.reset_mock()
    with django_capture_on_commit_callbacks(execute=True):
        assert api.post(f"/citas/{cita.pk}/aprobar").status_code == 409
    assert _envios(tareas) == []


def test_recordatorios_24h_y_2h_salen_una_sola_vez(cliente, limpieza, api, tareas, reloj):
    cita = _por_confirmar(cliente)
    Cita.objects.filter(pk=cita.pk).update(estado=Estado.PROGRAMADA)
    reloj.ahora = cita.inicio - timedelta(hours=20)
    assert avisos.recordar_citas() == 1
    assert avisos.recordar_citas() == 0  # no se repite
    reloj.ahora = cita.inicio - timedelta(minutes=90)
    assert avisos.recordar_citas() == 1
    assert avisos.recordar_citas() == 0
    titulos = [t for t, *_ in _envios(tareas)]
    assert len(titulos) == 2 and "pronto" in titulos[1]
    assert all(d["tipo"] == "recordatorio" for _, d, *_ in _envios(tareas))


def test_sin_recordatorio_para_citas_por_confirmar(cliente, limpieza, tareas, reloj):
    cita = _por_confirmar(cliente)
    reloj.ahora = cita.inicio - timedelta(hours=1)
    assert avisos.recordar_citas() == 0


def test_el_push_de_citas_solo_llega_a_quien_probo_su_whatsapp(settings):
    settings.FIREBASE_PROJECT_ID, settings.FIREBASE_CREDENCIALES = "p", "c"
    verificada = _cuenta()
    sin_probar = _cuenta(correo="otro@correo.pe", verificado=False)
    DispositivoCliente.objects.create(cliente=verificada, token_fcm="tok-1")
    DispositivoCliente.objects.create(cliente=sin_probar, token_fcm="tok-2")
    sesion = mock.Mock()
    sesion.post.return_value = mock.Mock(ok=True, status_code=200, text="")
    with mock.patch("mensajeria.push._sesion_fcm", return_value=sesion):
        enviados = avisos.enviar(["+51987654321"], "t", "c", {"tipo": "cita"}, None, True, avisos.CANAL_CITAS)
    assert enviados == 1
    mensaje = sesion.post.call_args.kwargs["json"]["message"]
    assert mensaje["token"] == "tok-1"
    assert mensaje["android"]["notification"]["channel_id"] == avisos.CANAL_CITAS


def test_la_cuenta_que_reservo_recibe_sus_avisos_sin_whatsapp_probado(settings):
    settings.FIREBASE_PROJECT_ID, settings.FIREBASE_CREDENCIALES = "p", "c"
    reservo = _cuenta(verificado=False)
    intrusa = _cuenta(correo="intrusa@correo.pe", verificado=False)
    DispositivoCliente.objects.create(cliente=reservo, token_fcm="tok-1")
    DispositivoCliente.objects.create(cliente=intrusa, token_fcm="tok-2")
    sesion = mock.Mock()
    sesion.post.return_value = mock.Mock(ok=True, status_code=200, text="")
    with mock.patch("mensajeria.push._sesion_fcm", return_value=sesion):
        enviados = avisos.enviar(
            ["+51987654321"], "t", "c", {"tipo": "cita"}, None, True, avisos.CANAL_CITAS, reservo.pk
        )
    assert enviados == 1 and sesion.post.call_args.kwargs["json"]["message"]["token"] == "tok-1"


def test_al_confirmar_el_aviso_lleva_la_cuenta_que_reservo(
    consultorio, limpieza, api, tareas, django_capture_on_commit_callbacks
):
    cuenta = _cuenta(verificado=False)
    app = ApiCliente(cuenta)
    hora = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"][0]["horas"][0]
    cita_id = Cita.objects.get(token_gestion=app.post(
        "/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": hora}
    ).json()["token"]).pk
    with django_capture_on_commit_callbacks(execute=True):
        assert api.post(f"/citas/{cita_id}/aprobar").status_code == 200
    [llamada] = [c for c in tareas.call_args_list if c.args[0] == "clientes.avisos.enviar"]
    assert llamada.args[8] == cuenta.pk


# --- Logros ------------------------------------------------------------------------------------------------


def test_logros_de_una_cuenta_nueva_estan_todos_por_lograr():
    datos = ApiCliente(_cuenta()).get("/logros").json()
    assert datos["visitas"] == 0 and datos["puntos"] == 0 and datos["racha"] == 0
    assert not any(l["logrado"] for l in datos["logros"])
    assert datos["nivel"] == {"nombre": "Nueva", "siguiente": "Habitual", "faltan": 3, "progreso": 0.0}


def test_la_primera_visita_terminada_desbloquea_su_logro(limpieza, api, reloj):
    from .test_clientes import _cita_terminada

    _cita_terminada(api, limpieza, reloj, hora=9)
    datos = ApiCliente(_cuenta()).get("/logros").json()
    logros = {l["clave"]: l for l in datos["logros"]}
    assert logros["primera"]["logrado"] and not logros["fiel"]["logrado"]
    assert logros["fiel"]["progreso"] == 1 and logros["fiel"]["meta"] == 5
    assert datos["visitas"] == 1 and datos["racha"] == 1 and datos["racha_activa"]


def test_sin_whatsapp_probado_no_ve_el_progreso_de_otro(limpieza, api, reloj):
    from .test_clientes import _cita_terminada

    _cita_terminada(api, limpieza, reloj, hora=9)
    assert ApiCliente(_cuenta(verificado=False)).get("/logros").json()["visitas"] == 0


def test_la_racha_se_pausa_sin_borrarse():
    from clientes.logros import _mes, _racha

    hoy = date(2026, 11, 9)
    seguidos = {_mes(date(2026, 7, 1)), _mes(date(2026, 8, 1)), _mes(date(2026, 9, 1))}
    assert _racha(seguidos, hoy) == (3, False)  # octubre sin visita: en pausa, pero la racha sigue ahí
    assert _racha(seguidos | {_mes(date(2026, 10, 1))}, hoy) == (4, True)
