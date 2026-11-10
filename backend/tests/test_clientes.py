"""Fase 3: app del cliente («Quiero reservar»), sellos, niveles, referidos, cupones y campañas."""
import re
from datetime import timedelta
from unittest import mock

import pytest
from django.core import mail
from django.test import Client

from citas.models import Cita, Estado
from clientes.autenticacion import emitir_acceso as acceso_cliente
from clientes.models import Cliente, DispositivoCliente, Sello
from consultorios.models import Usuario
from .conftest import AHORA, ApiDoctor, reservar

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def sin_push_cliente():
    with mock.patch("clientes.avisos.async_task") as m, mock.patch("clientes.api_negocio.async_task", create=True):
        yield m


@pytest.fixture
def con_sellos(consultorio):
    consultorio.opciones = {"fidelidad_activa": True, "fidelidad_meta": 3, "fidelidad_premio": "Limpieza gratis"}
    consultorio.save()
    return consultorio


class ApiCliente:
    def __init__(self, cliente: Cliente):
        self.c = Client(headers={"authorization": f"Bearer {acceso_cliente(cliente)}", "cf-connecting-ip": "200.1.1.9"})

    def get(self, ruta, **params):
        return self.c.get(f"/cliente/v1{ruta}", params)

    def post(self, ruta, datos=None):
        return self.c.post(f"/cliente/v1{ruta}", datos or {}, content_type="application/json")


def _registro(cliente, nombre="Rosa Paz", correo="rosa@correo.pe", celular="987654321", **extra):
    return cliente.post(
        "/cliente/v1/auth/registro",
        {"nombre": nombre, "correo": correo, "celular": celular, "acepta_politica": True, **extra},
        content_type="application/json",
    )


def _cuenta(correo="rosa@correo.pe", celular="+51987654321", nombre="Rosa Paz", **extra) -> Cliente:
    return Cliente.objects.create(nombre=nombre, correo=correo, celular=celular, **extra)


def _atender(api, cita_id, llegar=False):
    if llegar:
        assert api.post(f"/citas/{cita_id}/llego").status_code == 200
    assert api.post(f"/citas/{cita_id}/iniciar").status_code == 200
    r = api.post(f"/citas/{cita_id}/terminar")
    assert r.status_code == 200, r.content


def _cita_terminada(api, limpieza, reloj, hora=9, celular="987654321", llegar=False, retraso_min=30) -> int:
    """Agenda a las `hora` (desde antes) y la atiende: `retraso_min` es cuándo llega/la atienden respecto de la hora."""
    reloj.ahora = AHORA.replace(hour=hora) - timedelta(hours=1)
    r = api.post("/citas", {
        "tratamiento_id": limpieza.pk, "inicio": AHORA.replace(hour=hora).isoformat(),
        "nombre": "Rosa Paz", "celular": celular,
    })
    assert r.status_code == 201, r.content
    reloj.ahora = AHORA.replace(hour=hora) + timedelta(minutes=retraso_min)
    _atender(api, r.json()["cita_id"], llegar)
    return r.json()["cita_id"]


# --- Registro y sesión ---------------------------------------------------------------------------------


def test_registro_crea_la_cuenta_y_entrega_la_sesion(cliente):
    r = _registro(cliente, celular="987 654 321")
    assert r.status_code == 200, r.content
    datos = r.json()
    assert datos["nuevo"] is True and datos["acceso"] and datos["renovacion"]
    assert datos["cliente"]["celular"] == "+51987654321"
    assert len(datos["cliente"]["codigo_referido"]) == 6


def test_registro_exige_aceptar_la_politica(cliente):
    r = cliente.post("/cliente/v1/auth/registro", {"nombre": "Rosa", "correo": "r@c.pe", "celular": "987654321"},
                     content_type="application/json")
    assert r.status_code == 422


def test_el_mismo_correo_entra_solo_con_el_mismo_whatsapp(cliente):
    _registro(cliente)
    otra = _registro(cliente, celular="912345678")
    assert otra.status_code == 409 and otra.json()["codigo"] == "datos_no_coinciden"
    misma = _registro(cliente, correo="ROSA@correo.pe")
    assert misma.status_code == 200 and misma.json()["nuevo"] is False


def test_los_tokens_del_cliente_y_del_negocio_no_se_cruzan(doctor):
    rosa = _cuenta()
    assert Client(headers={"authorization": f"Bearer {acceso_cliente(rosa)}"}).get("/api/v1/agenda").status_code == 401
    assert ApiDoctor(doctor).c.get("/cliente/v1/yo").status_code == 401
    assert ApiCliente(rosa).get("/yo").json()["correo"] == "rosa@correo.pe"


def test_la_sesion_se_renueva_y_el_reuso_la_revoca(cliente):
    renovacion = _registro(cliente).json()["renovacion"]
    nueva = cliente.post("/cliente/v1/auth/refresh", {"renovacion": renovacion}, content_type="application/json")
    assert nueva.status_code == 200
    reuso = cliente.post("/cliente/v1/auth/refresh", {"renovacion": renovacion}, content_type="application/json")
    assert reuso.status_code == 401
    siguiente = nueva.json()["renovacion"]
    assert cliente.post("/cliente/v1/auth/refresh", {"renovacion": siguiente}, content_type="application/json").status_code == 401


# --- Negocios y reserva -----------------------------------------------------------------------------------


def test_mis_negocios_aparecen_por_el_whatsapp_con_el_que_reservo(cliente, consultorio, otro_consultorio, limpieza):
    assert reservar(cliente).status_code == 201
    rosa = _cuenta()
    negocios = ApiCliente(rosa).get("/mis-negocios").json()["negocios"]
    assert [n["slug"] for n in negocios] == ["sonrisa"]
    assert negocios[0]["ultima_cita"] is not None


def test_busca_solo_negocios_publicados(consultorio, otro_consultorio):
    otro_consultorio.publicado = False
    otro_consultorio.save()
    rosa = _cuenta()
    assert [n["slug"] for n in ApiCliente(rosa).get("/negocios", q="sonr").json()["negocios"]] == ["sonrisa"]
    assert ApiCliente(rosa).get("/negocios", q="ajeno").json()["negocios"] == []


def test_reserva_desde_la_app_queda_por_confirmar(consultorio, limpieza, api):
    rosa = _cuenta()
    app = ApiCliente(rosa)
    libres = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"]
    hora = libres[0]["horas"][0]
    r = app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": hora})
    assert r.status_code == 201, r.content
    cita = Cita.objects.get(token_gestion=r.json()["token"])
    assert cita.estado == Estado.POR_APROBAR
    assert cita.paciente.celular == "+51987654321" and cita.paciente.nombre == "Rosa Paz"
    citas = app.get("/mis-citas").json()
    assert [c["id"] for c in citas["proximas"]] == [cita.pk]
    assert "codigo" not in citas["proximas"][0]


def test_desde_la_app_tampoco_puede_cruzar_citas(consultorio, limpieza, cliente):
    assert reservar(cliente, inicio=AHORA.replace(hour=11)).status_code == 201
    r = ApiCliente(_cuenta()).post(
        "/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": AHORA.replace(hour=11).isoformat()}
    )
    assert r.status_code == 409


# --- Sellos, niveles y referidos ------------------------------------------------------------------------


def test_un_sello_por_visita_terminada_y_otro_si_llego_a_tiempo(con_sellos, limpieza, api, reloj):
    _cita_terminada(api, limpieza, reloj, hora=9, llegar=True, retraso_min=-5)
    motivos = sorted(Sello.objects.values_list("motivo", flat=True))
    assert motivos == ["puntual", "visita"]
    tarjeta = ApiCliente(_cuenta()).get("/negocios/sonrisa").json()["tarjeta"]
    assert tarjeta["sellos"] == 2 and tarjeta["meta"] == 3 and tarjeta["lista"] is False
    assert tarjeta["nivel"]["nombre"] == "Bronce"


def test_sin_programa_activo_no_se_dan_sellos(consultorio, limpieza, api, reloj):
    _cita_terminada(api, limpieza, reloj)
    assert Sello.objects.count() == 0


def test_tarjeta_llena_se_canjea_y_empieza_de_nuevo(con_sellos, limpieza, api, reloj):
    for hora in (9, 10, 11):
        _cita_terminada(api, limpieza, reloj, hora=hora)
    paciente_id = Cita.objects.first().paciente_id
    tarjeta = api.get(f"/pacientes/{paciente_id}/tarjeta").json()
    assert tarjeta["lista"] is True and tarjeta["sellos"] == 3
    r = api.post(f"/pacientes/{paciente_id}/canjear")
    assert r.status_code == 200 and r.json()["premio"] == "Limpieza gratis" and r.json()["sellos"] == 0
    assert api.post(f"/pacientes/{paciente_id}/canjear").status_code == 409


def test_el_referido_da_un_sello_a_ambos_en_su_primera_visita(con_sellos, limpieza, api, cliente, reloj):
    ana = _cuenta(correo="ana@correo.pe", celular="+51911111112", nombre="Ana Ríos")
    r = _registro(cliente, referido=ana.codigo_referido.lower())
    assert r.status_code == 200
    _cita_terminada(api, limpieza, reloj, hora=9)
    assert Sello.objects.filter(celular="+51987654321").count() == 2  # visita + referido
    assert Sello.objects.filter(celular="+51911111112", motivo="referido").count() == 1
    _cita_terminada(api, limpieza, reloj, hora=10)
    assert Sello.objects.filter(motivo="referido").count() == 2  # solo la primera visita cuenta


def test_codigo_de_invitacion_inexistente(cliente):
    assert _registro(cliente, referido="ZZZZZZ").status_code == 422


# --- Cupones y campañas -----------------------------------------------------------------------------------


def _crear_cupon(api, **extra):
    datos = {"titulo": "20 % en tu limpieza", "descuento_pct": 20,
             "vence_el": (AHORA + timedelta(days=30)).date().isoformat(), **extra}
    return api.post("/cupones", datos)


def test_el_cupon_le_llega_al_cliente_y_el_negocio_lo_ve_en_la_cita(con_sellos, limpieza, api, reloj):
    _cita_terminada(api, limpieza, reloj, hora=9)
    r = _crear_cupon(api, codigo="limpia20")
    assert r.status_code == 201, r.content
    assert r.json()["codigo"] == "LIMPIA20"

    app = ApiCliente(_cuenta())
    cupones = app.get("/beneficios").json()["cupones"]
    assert [c["codigo"] for c in cupones] == ["LIMPIA20"]
    hora = app.get("/negocios/sonrisa/disponibilidad", motivo="limpieza").json()["dias"][0]["horas"][0]
    reserva = app.post("/negocios/sonrisa/reservas", {"motivo": "limpieza", "inicio": hora, "cupon": cupones[0]["id"]})
    assert reserva.status_code == 201, reserva.content
    pendientes = api.get("/citas/por-aprobar").json()["citas"]
    assert pendientes[0]["cupon"] == {"codigo": "LIMPIA20", "titulo": "20 % en tu limpieza", "descuento": "20 %"}
    assert app.get("/beneficios").json()["cupones"] == []  # ya lo usó


def test_cupon_solo_para_su_segmento(con_sellos, limpieza, api):
    _crear_cupon(api, segmento="oro")
    assert ApiCliente(_cuenta()).get("/beneficios").json()["cupones"] == []


def test_la_cuenta_de_profesional_no_crea_cupones_ni_campanas(consultorio, limpieza):
    ana = Usuario.objects.create_user(
        "ana@sonrisa.test", "clave-segura-123", consultorio=consultorio, profesional=consultorio.profesional_principal()
    )
    assert _crear_cupon(ApiDoctor(ana)).status_code == 403
    assert ApiDoctor(ana).post("/campanas", {"titulo": "Hola", "mensaje": "Te extrañamos"}).status_code == 403


def test_campana_push_a_quien_tiene_app_y_whatsapp_al_resto(con_sellos, limpieza, api, reloj):
    _cita_terminada(api, limpieza, reloj, hora=9)
    _cita_terminada(api, limpieza, reloj, hora=10, celular="912345678")
    rosa = _cuenta()
    DispositivoCliente.objects.create(cliente=rosa, token_fcm="tok-rosa")
    assert api.get("/campanas/previa", segmento="todos").json() == {"destinatarios": 2, "con_app": 1}
    with mock.patch("django_q.tasks.async_task") as tarea:
        r = api.post("/campanas", {"titulo": "Te extrañamos", "mensaje": "esta semana tienes 20 % en limpiezas."})
    assert r.status_code == 201, r.content
    assert r.json()["con_app"] == 1 and len(r.json()["sin_app"]) == 1
    assert r.json()["sin_app"][0]["whatsapp_url"].startswith("https://wa.me/51912345678?text=")
    assert tarea.call_args.args[1] == ["+51987654321"]
    api.post("/campanas", {"titulo": "Otra", "mensaje": "segunda campaña"})
    tercera = api.post("/campanas", {"titulo": "Otra más", "mensaje": "tercera campaña"})
    assert tercera.status_code == 429


def test_quien_silencia_no_entra_en_las_campanas(con_sellos, limpieza, api, reloj):
    _cita_terminada(api, limpieza, reloj, hora=9)
    rosa = _cuenta()
    assert ApiCliente(rosa).post("/negocios/sonrisa/silenciar").json() == {"silenciado": True}
    assert api.get("/campanas/previa").json()["destinatarios"] == 0


# --- Verificación (construida, apagada por defecto) ----------------------------------------------------


def test_con_verificacion_activa_pide_el_codigo_del_correo(cliente, consultorio, limpieza, settings):
    settings.VERIFICAR_CLIENTES = True
    settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
    r = _registro(cliente)
    assert r.status_code == 200 and r.json() == {"verificar": True, "correo": "rosa@correo.pe"}
    codigo = re.search(r"\d{6}", mail.outbox[0].subject).group()
    datos = {"correo": "rosa@correo.pe", "celular": "987654321"}
    mal = cliente.post("/cliente/v1/auth/verificar", {**datos, "codigo": "000000" if codigo != "000000" else "111111"},
                       content_type="application/json")
    assert mal.status_code == 422
    ok = cliente.post("/cliente/v1/auth/verificar", {**datos, "codigo": codigo}, content_type="application/json")
    assert ok.status_code == 200, ok.content

    # El WhatsApp aún no está probado: no ve sus negocios hasta abrir el enlace de una de sus citas.
    reserva = reservar(cliente).json()
    rosa = Cliente.objects.get()
    app = ApiCliente(rosa)
    assert app.get("/mis-negocios").json()["negocios"] == []
    assert app.post("/vincular", {"token": reserva["token"]}).json()["celular_verificado"] is True
    assert [n["slug"] for n in app.get("/mis-negocios").json()["negocios"]] == ["sonrisa"]


def test_vincular_con_el_enlace_de_otro_numero_falla(cliente, consultorio, limpieza, settings):
    settings.VERIFICAR_CLIENTES = True
    reserva = reservar(cliente, celular="912345678").json()
    assert ApiCliente(_cuenta()).post("/vincular", {"token": reserva["token"]}).status_code == 409
