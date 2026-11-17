"""Fase 3: app del cliente («Quiero reservar»), sellos, niveles, referidos, cupones y campañas."""
import re
from datetime import timedelta
from unittest import mock

import pytest
from django.core import mail
from django.test import Client

from agenda.models import Tratamiento
from citas.models import Cita, Estado
from citas.servicios import firma_whatsapp
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
        {"nombre": nombre, "correo": correo, "celular": celular, "clave": "secreta-123", "acepta_politica": True, **extra},
        content_type="application/json",
    )


def _cuenta(correo="rosa@correo.pe", celular="+51987654321", nombre="Rosa Paz", verificado=True, **extra) -> Cliente:
    """Por defecto con el WhatsApp ya probado (abrió el enlace firmado de una de sus citas)."""
    if verificado:
        extra.setdefault("celular_verificado_en", AHORA)
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


def _entrar(cliente, correo="rosa@correo.pe", clave="secreta-123"):
    return cliente.post("/cliente/v1/auth/entrar", {"correo": correo, "clave": clave}, content_type="application/json")


def test_la_contrasena_se_guarda_cifrada_y_es_obligatoria(cliente):
    assert _registro(cliente, clave="corta").json()["codigo"] == "clave_corta"
    _registro(cliente)
    guardada = Cliente.objects.get(correo="rosa@correo.pe").clave
    assert guardada and "secreta-123" not in guardada


def test_crear_cuenta_con_un_correo_que_ya_existe_pide_entrar(cliente):
    _registro(cliente)
    otra = _registro(cliente, correo="ROSA@correo.pe")
    assert otra.status_code == 409 and otra.json()["codigo"] == "cuenta_existe"


def test_entrar_con_correo_y_contrasena(cliente):
    _registro(cliente)
    r = _entrar(cliente, correo=" Rosa@Correo.pe ")
    assert r.status_code == 200, r.content
    assert r.json()["acceso"] and r.json()["cliente"]["correo"] == "rosa@correo.pe"


@pytest.mark.parametrize(("correo", "clave"), [("rosa@correo.pe", "otra-clave-9"), ("nadie@correo.pe", "secreta-123")])
def test_entrar_mal_no_dice_si_el_correo_existe(cliente, correo, clave):
    _registro(cliente)
    r = _entrar(cliente, correo=correo, clave=clave)
    assert r.status_code == 401 and r.json()["codigo"] == "credenciales"


def test_una_cuenta_antigua_crea_su_contrasena_con_su_mismo_whatsapp(cliente):
    _cuenta(verificado=False)  # de antes de las contraseñas
    assert _entrar(cliente).json()["codigo"] == "sin_clave"
    ajeno = _registro(cliente, celular="912345678")
    assert ajeno.status_code == 409 and ajeno.json()["codigo"] == "datos_no_coinciden"
    suyo = _registro(cliente)
    assert suyo.status_code == 200 and suyo.json()["nuevo"] is False
    assert _entrar(cliente).status_code == 200


def test_cambiar_la_contrasena_pide_la_actual(cliente):
    _registro(cliente)
    app = ApiCliente(Cliente.objects.get(correo="rosa@correo.pe"))
    mal = app.c.put("/cliente/v1/yo/clave", {"actual": "no-es-esta", "nueva": "nueva-clave-1"}, content_type="application/json")
    assert mal.status_code == 422
    bien = app.c.put("/cliente/v1/yo/clave", {"actual": "secreta-123", "nueva": "nueva-clave-1"}, content_type="application/json")
    assert bien.status_code == 204
    assert _entrar(cliente).status_code == 401
    assert _entrar(cliente, clave="nueva-clave-1").status_code == 200


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
    _cita_terminada(api, limpieza, reloj, hora=11, celular="955555555")  # sin permiso para promociones
    from citas.models import Paciente
    Paciente.objects.filter(celular="+51912345678").update(acepta_publicidad_en=AHORA)  # lo marcó al reservar
    rosa = _cuenta(acepta_publicidad_en=AHORA)  # lo marcó en la app
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
    cita = Cita.objects.get(token_gestion=reserva["token"])
    r = app.post("/vincular", {"token": reserva["token"], "firma": firma_whatsapp(cita)})
    assert r.json()["celular_verificado"] is True
    assert [n["slug"] for n in app.get("/mis-negocios").json()["negocios"]] == ["sonrisa"]


def test_vincular_con_el_enlace_de_otro_numero_falla(cliente, consultorio, limpieza, settings):
    settings.VERIFICAR_CLIENTES = True
    reserva = reservar(cliente, celular="912345678").json()
    assert ApiCliente(_cuenta()).post("/vincular", {"token": reserva["token"]}).status_code == 409


# --- SEG-01: un número escrito no prueba nada ------------------------------------------------------------


def test_otro_correo_con_mi_celular_no_ve_mis_citas(cliente, consultorio, otro_consultorio, limpieza, con_sellos):
    """Quien se registra con el WhatsApp de otra persona no ve sus citas, sellos ni cupones en ningún negocio."""
    assert reservar(cliente).status_code == 201  # la cita de Rosa, con su número
    intruso = ApiCliente(_cuenta(correo="intruso@correo.pe", verificado=False))
    assert intruso.get("/mis-citas").json() == {"proximas": [], "pasadas": []}
    assert intruso.get("/mis-negocios").json()["negocios"] == []
    beneficios = intruso.get("/beneficios").json()
    assert beneficios["tarjetas"] == [] and beneficios["cupones"] == []
    ficha = intruso.get("/negocios/sonrisa").json()
    assert ficha["es_cliente"] is False and ficha["tarjeta"] is None and ficha["cupones"] == []
    assert "token" not in str(intruso.get("/mis-citas").json())


def test_vincular_exige_el_enlace_firmado_que_manda_el_negocio(cliente, consultorio, limpieza):
    """El intruso reserva con el número ajeno y recibe el token: sin la firma del WhatsApp no le sirve."""
    intruso_cuenta = _cuenta(correo="intruso@correo.pe", verificado=False)
    intruso = ApiCliente(intruso_cuenta)
    reserva = intruso.post("/negocios/sonrisa/reservas", {
        "motivo": "limpieza", "inicio": AHORA.replace(hour=11).isoformat(),
    }).json()
    assert intruso.post("/vincular", {"token": reserva["token"]}).status_code == 409
    assert intruso.post("/vincular", {"token": reserva["token"], "firma": "0" * 16}).status_code == 409
    intruso_cuenta.refresh_from_db()
    assert intruso_cuenta.celular_verificado_en is None

    # El enlace que el negocio manda al WhatsApp sí lleva la firma, y es lo único que verifica el número.
    cita = Cita.objects.get(token_gestion=reserva["token"])
    from citas.servicios import texto_para_paciente
    assert f"?v={firma_whatsapp(cita)}" in texto_para_paciente(cita, "confirmada", "https://sonrisa.denticita.test")
    assert intruso.post("/vincular", {"token": reserva["token"], "firma": firma_whatsapp(cita)}).status_code == 200


def test_sin_whatsapp_probado_no_usa_cupones(consultorio, limpieza):
    from clientes.models import Cupon

    cupon = Cupon.objects.create(consultorio=consultorio, codigo="HOLA", titulo="Hola", descuento_pct=10, vence_el=AHORA.date() + timedelta(days=30))
    r = ApiCliente(_cuenta(verificado=False)).post("/negocios/sonrisa/reservas", {
        "motivo": "limpieza", "inicio": AHORA.replace(hour=11).isoformat(), "cupon": cupon.pk,
    })
    assert r.status_code == 409 and r.json()["codigo"] == "cupon_invalido"


# --- DAT-02: promociones solo con un permiso aparte ------------------------------------------------------


def test_la_reserva_web_guarda_la_version_de_la_politica_y_el_permiso_de_promociones(cliente, consultorio, limpieza):
    from citas.models import Paciente

    assert reservar(cliente, inicio=AHORA.replace(hour=10), acepta_publicidad=False).status_code == 201
    paciente = Paciente.objects.get()
    assert paciente.politica_version == settings_politica() and paciente.acepta_publicidad_en is None
    assert reservar(cliente, inicio=AHORA.replace(hour=11), acepta_publicidad=True).status_code == 201
    paciente.refresh_from_db()
    assert paciente.acepta_publicidad_en is not None


def settings_politica():
    from django.conf import settings

    return settings.POLITICA_VERSION


def test_el_cliente_da_y_retira_el_permiso_de_promociones(cliente):
    r = _registro(cliente, acepta_publicidad=True)
    rosa = Cliente.objects.get()
    assert rosa.acepta_publicidad_en is not None and rosa.politica_version == settings_politica()
    assert r.json()["cliente"]["acepta_publicidad"] is True
    app = ApiCliente(rosa)
    r = app.c.put("/cliente/v1/yo", {"nombre": "Rosa Paz", "acepta_publicidad": False}, content_type="application/json")
    assert r.json()["acepta_publicidad"] is False
    rosa.refresh_from_db()
    assert rosa.acepta_publicidad_en is None


def test_sin_permiso_no_entra_en_ninguna_campana(con_sellos, limpieza, api, reloj):
    _cita_terminada(api, limpieza, reloj, hora=9)
    assert api.get("/campanas/previa", segmento="todos").json() == {"destinatarios": 0, "con_app": 0}


# --- DAT-03 / DAT-04: borrar la cuenta y los datos ------------------------------------------------------


def test_borrar_cuenta_cliente_anonimiza_y_corta_la_sesion(cliente, consultorio):
    rosa = _cuenta()
    DispositivoCliente.objects.create(cliente=rosa, token_fcm="tok-rosa")
    rosa.silenciados.add(consultorio)
    app = ApiCliente(rosa)
    assert app.c.delete("/cliente/v1/yo").status_code == 204
    rosa.refresh_from_db()
    assert rosa.activo is False and "rosa" not in rosa.correo and rosa.celular.startswith("eliminado-")
    assert rosa.nombre == "Cliente eliminado" and rosa.celular_verificado_en is None
    assert not DispositivoCliente.objects.exists() and not rosa.silenciados.exists()
    assert app.get("/yo").status_code == 401
    # Con el mismo correo puede crear una cuenta nueva desde cero.
    assert _registro(cliente).status_code == 200


def test_anonimizar_borra_sellos_cupones_y_avisos(con_sellos, limpieza, api, reloj):
    from citas import servicios
    from citas.models import Paciente
    from clientes.models import Canje, Cupon, CuponUsado
    from mensajeria.models import AvisoPendiente

    cita_id = _cita_terminada(api, limpieza, reloj, hora=9)
    paciente = Paciente.objects.get()
    cupon = Cupon.objects.create(consultorio=con_sellos, codigo="X", titulo="X", descuento_pct=5,
                                 vence_el=AHORA.date() + timedelta(days=9))
    CuponUsado.objects.create(cupon=cupon, cita_id=cita_id, celular=paciente.celular)
    Canje.objects.create(consultorio=con_sellos, celular=paciente.celular, premio="Limpieza")
    AvisoPendiente.objects.create(consultorio=con_sellos, clave=f"x:{cita_id}", titulo="Rosa Paz", cuerpo="Limpieza",
                                  datos={"cita_id": str(cita_id)}, proximo_intento=AHORA)
    celular = paciente.celular
    servicios.anonimizar_paciente(paciente)
    assert not Sello.objects.filter(celular=celular).exists() and Sello.objects.exists()
    assert not Canje.objects.filter(celular=celular).exists()
    assert not CuponUsado.objects.filter(celular=celular).exists()
    assert not AvisoPendiente.objects.exists()
    paciente.refresh_from_db()
    assert paciente.nombre == "Paciente eliminado" and paciente.acepta_publicidad_en is None


def test_el_negocio_elimina_los_datos_de_un_paciente_a_su_pedido(limpieza, api, reloj, consultorio):
    from citas.models import Paciente

    _cita_terminada(api, limpieza, reloj, hora=9)
    paciente = Paciente.objects.get()
    assert api.post(f"/pacientes/{paciente.pk}/eliminar-datos").status_code == 204
    paciente.refresh_from_db()
    assert paciente.nombre == "Paciente eliminado"


def test_no_elimina_datos_con_citas_por_venir_ni_desde_una_cuenta_de_profesional(cliente, consultorio, limpieza, api):
    from citas.models import Paciente

    assert reservar(cliente).status_code == 201
    paciente = Paciente.objects.get()
    Cita.objects.update(estado=Estado.PROGRAMADA)
    assert api.post(f"/pacientes/{paciente.pk}/eliminar-datos").status_code == 409
    usuario = Usuario.objects.create_user("p@sonrisa.test", "clave-segura-123", consultorio=consultorio,
                                          profesional=consultorio.profesional_principal())
    assert ApiDoctor(usuario).post(f"/pacientes/{paciente.pk}/eliminar-datos").status_code == 403


def test_logout_borra_el_dispositivo_del_telefono(cliente):
    """SEG-07: tras cerrar sesión, ese teléfono no sigue recibiendo avisos."""
    _registro(cliente)
    rosa = Cliente.objects.get()
    DispositivoCliente.objects.create(cliente=rosa, token_fcm="tok-1")
    DispositivoCliente.objects.create(cliente=rosa, token_fcm="tok-otro")
    from clientes.autenticacion import tokens as tokens_cliente

    renovacion = tokens_cliente(rosa)["renovacion"]
    r = cliente.post("/cliente/v1/auth/logout", {"renovacion": renovacion, "token_fcm": "tok-1"},
                     content_type="application/json")
    assert r.status_code == 204
    assert list(DispositivoCliente.objects.values_list("token_fcm", flat=True)) == ["tok-otro"]


# --- Historial ---------------------------------------------------------------------------------------------


def _al_pasado(cliente, dias: int, slug="sonrisa", estado=Estado.TERMINADA) -> Cita:
    """Reserva por la web con el número de Rosa y la mueve [dias] atrás, ya terminada."""
    r = reservar(cliente, slug=slug)
    assert r.status_code == 201, r.content
    cita = Cita.objects.get(token_gestion=r.json()["token"])
    corrimiento = timedelta(days=dias)
    Cita.objects.filter(pk=cita.pk).update(
        inicio=cita.inicio - corrimiento, fin=cita.fin - corrimiento, fin_ocupado=cita.fin_ocupado - corrimiento,
        estado=estado,
    )
    return cita


def _copia_en_el_pasado(cita: Cita, dias: int) -> Cita:
    """Otra visita igual, [dias] antes (sin pasar por la reserva y su límite por número)."""
    original = Cita.objects.get(pk=cita.pk)
    original.pk = None
    original.token_gestion = f"t{dias}-{original.token_gestion}"[:64]
    corrimiento = timedelta(days=dias)
    original.inicio, original.fin = original.inicio - corrimiento, original.fin - corrimiento
    original.fin_ocupado -= corrimiento
    original.save()
    return original


def test_el_historial_se_pide_de_20_en_20(cliente, consultorio, limpieza):
    base = _al_pasado(cliente, 1)
    ids = [base.pk] + [_copia_en_el_pasado(base, dias).pk for dias in range(1, 23)]  # 23 visitas
    app = ApiCliente(_cuenta())
    primera = app.get("/mis-citas/historial").json()
    assert [c["id"] for c in primera["citas"]] == ids[:20] and primera["hay_mas"] is True
    assert primera["visitas"] == 23 and primera["negocios"] == [{"slug": "sonrisa", "nombre": consultorio.nombre}]
    segunda = app.get("/mis-citas/historial", antes=primera["citas"][-1]["inicio"]).json()
    assert [c["id"] for c in segunda["citas"]] == ids[20:] and segunda["hay_mas"] is False


def test_el_historial_se_filtra_por_negocio_y_no_trae_las_proximas(cliente, consultorio, otro_consultorio, limpieza):
    Tratamiento.objects.create(consultorio=otro_consultorio, nombre="Limpieza", slug="limpieza", duracion_min=30)
    _al_pasado(cliente, 2)
    ajena = _al_pasado(cliente, 3, slug="ajeno", estado=Estado.NO_ASISTIO)
    assert reservar(cliente).status_code == 201  # próxima: no va al historial
    app = ApiCliente(_cuenta())
    todo = app.get("/mis-citas/historial").json()
    assert len(todo["citas"]) == 2 and todo["visitas"] == 1
    solo_ajeno = app.get("/mis-citas/historial", negocio="ajeno").json()["citas"]
    assert [c["id"] for c in solo_ajeno] == [ajena.pk] and solo_ajeno[0]["estado"] == Estado.NO_ASISTIO


def test_sin_whatsapp_probado_el_historial_trae_solo_lo_reservado_desde_la_app(cliente, consultorio, limpieza):
    _al_pasado(cliente, 2)  # hecha en la web con ese número: no se muestra todavía
    cuenta = _cuenta(verificado=False)
    propia = _al_pasado(cliente, 5)
    Cita.objects.filter(pk=propia.pk).update(cliente=cuenta)
    historial = ApiCliente(cuenta).get("/mis-citas/historial").json()
    assert [c["id"] for c in historial["citas"]] == [propia.pk] and historial["completo"] is False
    intrusa = ApiCliente(_cuenta(correo="intrusa@correo.pe", verificado=False)).get("/mis-citas/historial").json()
    assert intrusa["citas"] == [] and intrusa["negocios"] == []


def test_el_historial_rechaza_una_fecha_de_pagina_invalida(consultorio):
    assert ApiCliente(_cuenta()).get("/mis-citas/historial", antes="ayer").status_code == 422
