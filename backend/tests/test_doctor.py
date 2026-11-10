"""App del doctor: sesión, agenda, consulta, cita manual y configuración (RF-20 a RF-34)."""
from datetime import datetime, timedelta, timezone as zona
from urllib.parse import unquote

import jwt
import pytest
from django.conf import settings
from django.test import Client

from agenda.models import HorarioSemanal, Tratamiento
from citas.models import Cita, Estado, EventoCita, Paciente
from consultorios.models import Dispositivo, SesionRenovacion, Usuario
from .conftest import AHORA, ApiDoctor, reservar

pytestmark = pytest.mark.django_db


def login(correo="doc@sonrisa.test", password="clave-segura-123"):
    return Client().post("/api/v1/auth/login", {"correo": correo, "password": password}, content_type="application/json")


def refresh(token):
    return Client().post("/api/v1/auth/refresh", {"renovacion": token}, content_type="application/json")


def cita_hoy(api, limpieza, hora=10, celular="987111222", nombre="Rosa Paz"):
    r = api.post(
        "/citas",
        {"tratamiento_id": limpieza.pk, "inicio": AHORA.replace(hour=hora).isoformat(), "nombre": nombre, "celular": celular},
    )
    assert r.status_code == 201, r.content
    return r.json()["cita_id"]


def agenda_cita(api, cita_id):
    return next(c for c in api.get("/agenda").json()["citas"] if c["id"] == cita_id)


# --- Sesión -----------------------------------------------------------------------------------


def test_login_correcto(doctor):
    r = login()
    assert r.status_code == 200
    datos = r.json()
    assert datos["usuario"]["consultorio"] == "Sonrisa"
    assert datos["acceso"] and datos["renovacion"]


def test_la_contrasena_se_guarda_con_argon2(doctor):
    assert doctor.password.startswith("argon2")


def test_login_acepta_correo_con_mayusculas(doctor):
    assert login(correo="DOC@Sonrisa.TEST ").status_code == 200


def test_cinco_fallos_bloquean_15_min_incluso_con_la_clave_correcta(doctor, reloj):
    for _ in range(5):
        assert login(password="mala").status_code == 401
    r = login()
    assert r.status_code == 429
    assert r.json()["codigo"] == "cuenta_en_espera"
    reloj.avanzar(minutes=14, seconds=59)
    assert login().status_code == 429
    reloj.avanzar(seconds=2)
    assert login().status_code == 200


def test_login_exitoso_reinicia_el_contador(doctor):
    for _ in range(4):
        login(password="mala")
    assert login().status_code == 200
    for _ in range(4):
        login(password="mala")
    assert login().status_code == 200


def test_el_correo_inexistente_responde_igual_que_la_clave_mala(doctor):
    inexistente = login(correo="nadie@x.test")
    mala = login(password="mala")
    assert inexistente.status_code == mala.status_code == 401
    assert inexistente.json() == mala.json()


def test_el_administrador_sin_consultorio_no_entra_a_la_app(db):
    Usuario.objects.create_superuser("admin@x.test", "clave-segura-123")
    assert login(correo="admin@x.test").status_code == 401


def test_usuario_inactivo_no_entra(doctor):
    doctor.activo = False
    doctor.save()
    assert login().status_code == 401


def test_token_de_acceso_dura_15_min(doctor):
    token = login().json()["acceso"]
    datos = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
    assert datos["exp"] - datos["iat"] == 15 * 60


def test_token_vencido_o_invalido_se_rechaza(doctor):
    vencido = jwt.encode(
        {"sub": str(doctor.pk), "tipo": "acceso", "exp": datetime.now(zona.utc) - timedelta(seconds=1)},
        settings.JWT_SECRET,
        algorithm="HS256",
    )
    falso = jwt.encode(
        {"sub": str(doctor.pk), "tipo": "acceso", "exp": datetime.now(zona.utc) + timedelta(hours=1)},
        "otra-clave-otra-clave-otra-clave-otra-clave",
        algorithm="HS256",
    )
    for token in (vencido, falso, "basura"):
        assert Client(headers={"authorization": f"Bearer {token}"}).get("/api/v1/agenda").status_code == 401
    assert Client().get("/api/v1/agenda").status_code == 401


def test_usuario_desactivado_pierde_el_acceso_al_instante(doctor, api):
    assert api.get("/agenda").status_code == 200
    doctor.activo = False
    doctor.save()
    assert api.get("/agenda").status_code == 401


def test_renovacion_rotativa(doctor):
    primero = login().json()["renovacion"]
    r = refresh(primero)
    assert r.status_code == 200
    assert r.json()["renovacion"] != primero
    assert not SesionRenovacion.objects.filter(token_hash=primero).exists()  # solo se guarda el hash


def test_reusar_un_token_gastado_revoca_toda_la_sesion(doctor):
    primero = login().json()["renovacion"]
    segundo = refresh(primero).json()["renovacion"]
    assert refresh(primero).status_code == 401
    assert refresh(segundo).status_code == 401  # el ladrón y la víctima quedan fuera


def test_renovacion_vence_tras_un_anio_sin_abrir_la_app(doctor, reloj):
    token = login().json()["renovacion"]
    reloj.avanzar(days=365, seconds=1)
    assert refresh(token).status_code == 401


def test_la_sesion_no_se_cierra_mientras_se_use(doctor, reloj):
    token = login().json()["renovacion"]
    for _ in range(5):  # cinco años abriendo la app cada 300 días
        reloj.avanzar(days=300)
        r = refresh(token)
        assert r.status_code == 200
        token = r.json()["renovacion"]


def test_cerrar_sesion_invalida_la_renovacion(doctor):
    token = login().json()["renovacion"]
    assert Client().post("/api/v1/auth/logout", {"renovacion": token}, content_type="application/json").status_code == 204
    assert refresh(token).status_code == 401


def test_cerrar_sesion_deja_de_avisar_a_ese_telefono(doctor):
    """SEG-07: un celular prestado o devuelto no sigue recibiendo los avisos del negocio."""
    from consultorios.models import Dispositivo

    Dispositivo.objects.create(usuario=doctor, token_fcm="tok-este")
    Dispositivo.objects.create(usuario=doctor, token_fcm="tok-otro")
    token = login().json()["renovacion"]
    r = Client().post("/api/v1/auth/logout", {"renovacion": token, "token_fcm": "tok-este"},
                      content_type="application/json")
    assert r.status_code == 204
    assert list(Dispositivo.objects.values_list("token_fcm", flat=True)) == ["tok-otro"]


def test_registrar_dispositivo_es_idempotente(api, doctor):
    for _ in range(2):
        assert api.post("/dispositivos", {"token_fcm": "abc"}).status_code == 204
    assert Dispositivo.objects.get().usuario == doctor


# --- Agenda y consulta ------------------------------------------------------------------------


def test_agenda_del_dia_incluye_estado_estimacion_y_huecos(api, limpieza):
    cita_id = cita_hoy(api, limpieza, hora=10)
    datos = api.get("/agenda").json()
    assert datos["fecha"] == "2026-11-09"
    cita = next(c for c in datos["citas"] if c["id"] == cita_id)
    assert cita["estado"] == "programada"
    assert cita["inicio_estimado"].startswith("2026-11-09T10:00")
    assert datos["retraso_min"] == 0
    # 9:00-10:00 libre y 10:40-13:00 libre (30 min + margen 10).
    assert [(h["inicio"][11:16], h["fin"][11:16]) for h in datos["huecos"]] == [("09:00", "10:00"), ("10:40", "13:00")]


@pytest.mark.verificacion_whatsapp
def test_agenda_no_muestra_prerreservas_sin_verificar_ni_canceladas(api, cliente, limpieza):
    reservar(cliente)
    cancelada = cita_hoy(api, limpieza, hora=9)
    api.post(f"/citas/{cancelada}/cancelar")
    assert api.get("/agenda").json()["citas"] == []


def test_huecos_consideran_la_prerreserva_retenida(api, cliente, limpieza):
    reservar(cliente, inicio=AHORA.replace(hour=11))
    huecos = api.get("/agenda").json()["huecos"]
    assert all(not (h["inicio"][11:16] <= "11:00" < h["fin"][11:16]) for h in huecos)


def test_iniciar_mas_diez_recalcula_a_la_siguiente(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9, minute=25)
    r = api.post(f"/citas/{primera}/iniciar")
    assert r.status_code == 200
    # Empieza 9:25: termina 9:55, con margen 10 min → la siguiente sigue a las 10:05.
    siguiente = next(c for c in r.json()["agenda"]["citas"] if c["id"] == segunda)
    assert siguiente["inicio_estimado"].startswith("2026-11-09T10:05")
    r = api.post(f"/citas/{primera}/extender", {"minutos": 20})
    siguiente = next(c for c in r.json()["agenda"]["citas"] if c["id"] == segunda)
    assert siguiente["inicio_estimado"].startswith("2026-11-09T10:25")
    assert r.json()["agenda"]["retraso_min"] == 25


def test_extender_no_choca_con_la_restriccion_de_la_base(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9)
    api.post(f"/citas/{primera}/iniciar")
    for _ in range(4):
        assert api.post(f"/citas/{primera}/extender", {"minutos": 20}).status_code == 200
    assert Cita.objects.get(pk=primera).minutos_extra == 80


def test_el_paciente_ve_la_hora_estimada_recalculada(api, cliente, reloj, limpieza, consultorio):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    token = Cita.objects.get(pk=segunda).token_gestion
    reloj.ahora = AHORA.replace(hour=9, minute=30)
    api.post(f"/citas/{primera}/iniciar")
    api.post(f"/citas/{primera}/extender", {"minutos": 10})
    datos = cliente.get(f"/public/v1/citas/{token}").json()
    assert datos["hora_estimada"].startswith("2026-11-09T10:20")
    assert datos["retraso_min"] == 20


def test_terminar_guarda_la_duracion_real(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9, minute=2)
    api.post(f"/citas/{cita}/iniciar")
    reloj.ahora = AHORA.replace(hour=9, minute=47)
    assert api.post(f"/citas/{cita}/terminar").status_code == 200
    guardada = Cita.objects.get(pk=cita)
    assert guardada.estado == Estado.TERMINADA
    assert guardada.fin_real - guardada.inicio_real == timedelta(minutes=45)


def test_no_vino_suma_inasistencia_y_libera_la_cola(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9, minute=20)
    r = api.post(f"/citas/{primera}/no-asistio")
    assert r.status_code == 200
    assert Cita.objects.get(pk=primera).paciente.inasistencias == 1
    siguiente = next(c for c in r.json()["agenda"]["citas"] if c["id"] == segunda)
    assert siguiente["inicio_estimado"].startswith("2026-11-09T10:00")


@pytest.mark.parametrize(
    "accion,cuerpo",
    [("terminar", None), ("extender", {"minutos": 10}), ("aprobar", None), ("rechazar", None)],
)
def test_acciones_fuera_de_orden_dan_conflicto(api, limpieza, accion, cuerpo):
    cita = cita_hoy(api, limpieza, hora=9)
    assert api.post(f"/citas/{cita}/{accion}", cuerpo).status_code == 409


def test_cita_terminada_no_se_puede_reiniciar_ni_cancelar(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9)
    api.post(f"/citas/{cita}/iniciar")
    api.post(f"/citas/{cita}/terminar")
    for accion in ("iniciar", "no-asistio", "cancelar", "terminar"):
        assert api.post(f"/citas/{cita}/{accion}").status_code == 409


def test_extender_solo_10_o_20(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9)
    api.post(f"/citas/{cita}/iniciar")
    assert api.post(f"/citas/{cita}/extender", {"minutos": 15}).status_code == 422


def test_solo_una_cita_en_curso(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9)
    api.post(f"/citas/{primera}/iniciar")
    r = api.post(f"/citas/{segunda}/iniciar")
    assert r.status_code == 409 and r.json()["codigo"] == "otra_en_curso"


def test_no_se_inicia_una_cita_de_otro_dia(api, limpieza):
    r = api.post(
        "/citas",
        {"tratamiento_id": limpieza.pk, "inicio": (AHORA + timedelta(days=1, hours=2)).isoformat(), "nombre": "Ana", "celular": "987111444"},
    )
    assert api.post(f"/citas/{r.json()['cita_id']}/iniciar").json()["codigo"] == "no_es_hoy"


def test_cada_cambio_guarda_usuario_hora_y_valor_anterior(api, doctor, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9)
    api.post(f"/citas/{cita}/iniciar")
    evento = EventoCita.objects.filter(cita_id=cita, valor_nuevo=Estado.EN_CURSO).get()
    assert evento.usuario == doctor
    assert evento.valor_anterior == Estado.PROGRAMADA
    assert evento.fecha == reloj.ahora


def test_semana_trae_siete_dias_con_citas_y_bloqueos(api, limpieza):
    cita_hoy(api, limpieza, hora=9)
    api.post("/bloqueos", {"inicio": (AHORA + timedelta(days=2)).isoformat(), "fin": (AHORA + timedelta(days=4)).isoformat()})
    dias = api.get("/agenda/semana").json()["dias"]
    assert len(dias) == 7
    assert len(dias[0]["citas"]) == 1
    assert [len(d["bloqueos"]) for d in dias] == [0, 0, 1, 1, 1, 0, 0]


# --- Cita manual ------------------------------------------------------------------------------


def test_cita_por_telefono_queda_programada_sin_verificacion(api, limpieza):
    cita = Cita.objects.get(pk=cita_hoy(api, limpieza, hora=9))
    assert cita.estado == Estado.PROGRAMADA and cita.origen == "doctor"
    assert cita.paciente.verificado_en is None


def test_cita_por_telefono_entrega_el_enlace_para_enviarselo_al_paciente(api, limpieza):
    r = api.post(
        "/citas",
        {"tratamiento_id": limpieza.pk, "inicio": AHORA.replace(hour=9).isoformat(), "nombre": "Ana Ruiz", "celular": "987111444"},
    ).json()
    url = unquote(r["whatsapp_url"])
    assert url.startswith("https://wa.me/51987111444?text=")
    assert f"/c/{Cita.objects.get().token_gestion}/" in url


def test_cita_por_telefono_solo_en_horas_libres(api, limpieza):
    cita_hoy(api, limpieza, hora=10)
    cuerpo = {"tratamiento_id": limpieza.pk, "nombre": "Ana", "celular": "987111444"}
    assert api.post("/citas", {**cuerpo, "inicio": AHORA.replace(hour=10, minute=15).isoformat()}).status_code == 409
    assert api.post("/citas", {**cuerpo, "inicio": AHORA.replace(hour=15).isoformat()}).status_code == 409


def test_disponibilidad_del_doctor_no_pide_anticipacion(api, limpieza):
    dias = api.get("/citas/disponibilidad", tratamiento_id=limpieza.pk).json()["dias"]
    assert dias[0]["horas"][0].startswith("2026-11-09T09:00")


def test_cita_por_telefono_de_un_tratamiento_no_reservable(api, consultorio):
    interno = Tratamiento.objects.create(consultorio=consultorio, nombre="Cirugía", duracion_min=60, reservable=False)
    assert cita_hoy(api, interno, hora=9)


# --- Aprobar, cancelar y mover ----------------------------------------------------------------


@pytest.fixture
def solicitud(cliente, limpieza):
    token = reservar(cliente, inicio=AHORA.replace(hour=11), nombre="Luz Rojas").json()["token"]
    cliente.post(f"/public/v1/citas/{token}/sin-whatsapp")
    return Cita.objects.get(token_gestion=token)


def test_aprobar_pasa_a_programada_y_devuelve_el_aviso(api, solicitud):
    assert api.get("/agenda").json()["por_aprobar"] == 1
    assert api.get("/citas/por-aprobar").json()["citas"][0]["paciente"]["nombre"] == "Luz Rojas"
    r = api.post(f"/citas/{solicitud.pk}/aprobar")
    assert r.status_code == 200
    assert r.json()["estado"] == Estado.PROGRAMADA
    assert "wa.me/51987654321" in r.json()["whatsapp_url"]
    assert api.get("/agenda").json()["por_aprobar"] == 0


def test_rechazar_libera_el_horario(api, cliente, solicitud):
    assert api.post(f"/citas/{solicitud.pk}/rechazar").json()["estado"] == Estado.CANCELADA
    assert reservar(cliente, inicio=AHORA.replace(hour=11), celular="987000000").status_code == 201


def test_cancelar_devuelve_el_mensaje_ya_escrito(api, limpieza):
    cita = cita_hoy(api, limpieza, hora=9, nombre="Rosa Paz")
    r = api.post(f"/citas/{cita}/cancelar").json()
    url = unquote(r["whatsapp_url"])
    assert url.startswith("https://wa.me/51987111222?text=")
    assert "Hola Rosa" in url and "cancelada" in url


def test_mover_cita_y_avisar_con_enlace(api, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    r = api.post(f"/citas/{cita}/reprogramar", {"inicio": AHORA.replace(hour=11).isoformat()})
    assert r.status_code == 200
    url = unquote(r.json()["whatsapp_url"])
    assert "11:00" in url
    assert f"sonrisa.denticita.test/c/{Cita.objects.get(pk=cita).token_gestion}/" in url


def test_mover_a_una_hora_ocupada(api, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    cita_hoy(api, limpieza, hora=11, celular="987111333")
    assert api.post(f"/citas/{cita}/reprogramar", {"inicio": AHORA.replace(hour=11).isoformat()}).status_code == 409


# --- Configuración ----------------------------------------------------------------------------


def test_horario_se_reemplaza_y_se_refleja_en_la_web_al_instante(api, cliente, limpieza, consultorio):
    r = api.put("/horario", {"tramos": [{"dia_semana": 0, "hora_inicio": "15:00", "hora_fin": "16:00"}]})
    assert r.status_code == 200
    assert HorarioSemanal.objects.filter(consultorio=consultorio).count() == 1
    dias = cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"}).json()["dias"]
    assert dias[0]["horas"][0].startswith("2026-11-09T15:00")


def test_horario_acepta_varios_tramos_por_dia(api):
    tramos = [
        {"dia_semana": 0, "hora_inicio": "09:00", "hora_fin": "13:00"},
        {"dia_semana": 0, "hora_inicio": "15:00", "hora_fin": "19:00"},
    ]
    assert len(api.put("/horario", {"tramos": tramos}).json()["tramos"]) == 2


@pytest.mark.parametrize(
    "tramo",
    [
        {"dia_semana": 0, "hora_inicio": "13:00", "hora_fin": "09:00"},
        {"dia_semana": 7, "hora_inicio": "09:00", "hora_fin": "10:00"},
    ],
)
def test_horario_invalido_no_borra_el_actual(api, consultorio, tramo):
    antes = HorarioSemanal.objects.filter(consultorio=consultorio).count()
    assert api.put("/horario", {"tramos": [tramo]}).status_code == 422
    assert HorarioSemanal.objects.filter(consultorio=consultorio).count() == antes


def test_bloqueo_lista_las_citas_afectadas_antes_de_confirmar(api, limpieza):
    cita = cita_hoy(api, limpieza, hora=10)
    afectadas = api.get(
        "/bloqueos/impacto", inicio=AHORA.replace(hour=9).isoformat(), fin=AHORA.replace(hour=11).isoformat()
    ).json()["citas"]
    assert [c["id"] for c in afectadas] == [cita]


def test_crear_y_borrar_bloqueo_actualiza_la_disponibilidad(api, cliente, limpieza):
    r = api.post("/bloqueos", {"inicio": AHORA.isoformat(), "fin": (AHORA + timedelta(days=1)).isoformat(), "motivo": "Congreso"})
    assert r.status_code == 201
    dias = cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"}).json()["dias"]
    assert "2026-11-09" not in [d["fecha"] for d in dias]
    assert api.delete(f"/bloqueos/{r.json()['id']}").status_code == 204
    dias = cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"}).json()["dias"]
    assert "2026-11-09" in [d["fecha"] for d in dias]


def test_bloqueo_con_rango_invertido(api):
    assert api.post("/bloqueos", {"inicio": AHORA.isoformat(), "fin": (AHORA - timedelta(hours=1)).isoformat()}).status_code == 422


def test_crear_y_editar_tratamiento(api, cliente):
    r = api.post("/tratamientos", {"nombre": "Extracción simple", "duracion_min": 40, "margen_min": 10, "precio_desde": "120.50"})
    assert r.status_code == 201
    datos = r.json()
    assert datos["slug"] == "extraccion-simple"
    r = api.put(f"/tratamientos/{datos['id']}", {"nombre": "Extracción", "duracion_min": 45, "reservable": False})
    assert r.json()["duracion_min"] == 45
    perfil = cliente.get("/public/v1/sonrisa/perfil").json()
    assert perfil["motivos"] == []


@pytest.mark.parametrize("cuerpo", [{"nombre": "", "duracion_min": 30}, {"nombre": "X", "duracion_min": 0}, {"nombre": "X", "duracion_min": 30, "margen_min": 500}])
def test_tratamiento_invalido(api, cuerpo):
    assert api.post("/tratamientos", cuerpo).status_code == 422


def test_dos_tratamientos_con_el_mismo_nombre_no_chocan(api):
    assert api.post("/tratamientos", {"nombre": "Control", "duracion_min": 20}).json()["slug"] == "control"
    assert api.post("/tratamientos", {"nombre": "Control", "duracion_min": 20}).json()["slug"] == "control-2"


def test_borrar_tratamiento_con_historial_solo_lo_oculta(api, limpieza):
    cita_hoy(api, limpieza, hora=9)
    assert api.delete(f"/tratamientos/{limpieza.pk}").status_code == 204
    limpieza.refresh_from_db()
    assert not limpieza.reservable and not limpieza.visible


def test_borrar_tratamiento_sin_citas_lo_elimina(api, limpieza):
    api.delete(f"/tratamientos/{limpieza.pk}")
    assert not Tratamiento.objects.filter(pk=limpieza.pk).exists()


# --- Pacientes --------------------------------------------------------------------------------


def test_busqueda_por_nombre_y_celular(api, limpieza):
    cita_hoy(api, limpieza, hora=9, nombre="Rosa Paz", celular="987111222")
    cita_hoy(api, limpieza, hora=10, nombre="Luis Mamani", celular="987333444")
    assert [p["nombre"] for p in api.get("/pacientes", q="rosa").json()["pacientes"]] == ["Rosa Paz"]
    assert [p["nombre"] for p in api.get("/pacientes", q="987 333").json()["pacientes"]] == ["Luis Mamani"]
    assert len(api.get("/pacientes").json()["pacientes"]) == 2


@pytest.mark.verificacion_whatsapp
def test_prerreserva_sin_verificar_no_aparece_como_paciente(api, cliente, limpieza):
    reservar(cliente)
    assert api.get("/pacientes").json()["pacientes"] == []


def test_historial_del_paciente(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    paciente = Cita.objects.get(pk=cita).paciente
    reloj.ahora = AHORA.replace(hour=9, minute=30)
    api.post(f"/citas/{cita}/no-asistio")
    datos = api.get(f"/pacientes/{paciente.pk}").json()
    assert datos["inasistencias"] == 1
    assert datos["citas"][0]["estado"] == Estado.NO_ASISTIO


def test_bloquear_numero_impide_reservar_y_se_puede_revertir(api, cliente, limpieza):
    cita = cita_hoy(api, limpieza, hora=9, celular="987654321")
    paciente = Cita.objects.get(pk=cita).paciente
    assert api.post(f"/pacientes/{paciente.pk}/bloquear").json()["bloqueado"] is True
    assert reservar(cliente, inicio=AHORA.replace(hour=11)).status_code == 403
    assert api.post(f"/pacientes/{paciente.pk}/bloquear", {"bloqueado": False}).json()["bloqueado"] is False
    assert reservar(cliente, inicio=AHORA.replace(hour=11)).status_code == 201
    assert Paciente.objects.get(pk=paciente.pk).bloqueado is False


def test_acceso_con_otro_doctor_del_mismo_consultorio(consultorio, limpieza):
    otro = Usuario.objects.create_user("otro@sonrisa.test", "clave-segura-123", consultorio=consultorio)
    assert ApiDoctor(otro).get("/tratamientos").json()["tratamientos"][0]["nombre"] == "Limpieza"


# --- Llegó / Me demoro / Atendida sin cronómetro -----------------------------------------------------


def test_me_demoro_antes_de_iniciar_corre_la_hora_y_ofrece_avisar(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9, minute=5)
    r = api.post(f"/citas/{primera}/demora", {"minutos": 15})
    assert r.status_code == 200
    # Ya iba 5 min tarde: +15 es desde ahora → empezaría 9:20.
    estimada = next(c for c in r.json()["agenda"]["citas"] if c["id"] == primera)
    assert estimada["inicio_estimado"].startswith("2026-11-09T09:20")
    avisos = r.json()["avisos"]
    assert [a["cita_id"] for a in avisos] == [primera]
    assert avisos[0]["retraso_min"] == 20
    assert "retraso" in unquote(avisos[0]["whatsapp_url"])
    assert segunda not in [a["cita_id"] for a in avisos]  # 9:20 + 30 + 10 de margen: la de 10:00 no se mueve
    assert EventoCita.objects.filter(cita_id=primera, tipo="demora").exists()


def test_me_demoro_en_curso_avisa_al_siguiente(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9, minute=25)
    api.post(f"/citas/{primera}/iniciar")
    r = api.post(f"/citas/{primera}/demora", {"minutos": 15})
    assert r.status_code == 200
    avisos = r.json()["avisos"]
    assert [a["cita_id"] for a in avisos] == [segunda]
    assert avisos[0]["inicio_estimado"].startswith("2026-11-09T10:20")


def test_me_demoro_solo_minutos_permitidos(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9)
    assert api.post(f"/citas/{cita}/demora", {"minutos": 7}).status_code == 422


def test_atendida_sin_cronometro_requiere_llegada(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9, minute=3)
    r = api.post(f"/citas/{cita}/terminar")
    assert r.status_code == 409 and r.json()["codigo"] == "sin_llegada"
    api.post(f"/citas/{cita}/llego")
    assert api.post(f"/citas/{cita}/terminar").status_code == 200
    guardada = Cita.objects.get(pk=cita)
    assert guardada.estado == Estado.TERMINADA
    assert guardada.inicio_real is None and guardada.fin_real is None


def test_iniciar_registra_la_llegada(api, reloj, limpieza):
    cita = cita_hoy(api, limpieza, hora=9)
    reloj.ahora = AHORA.replace(hour=9, minute=4)
    api.post(f"/citas/{cita}/iniciar")
    assert Cita.objects.get(pk=cita).llegada_en is not None


def test_metricas_de_asistencia_y_duracion(api, reloj, limpieza):
    primera = cita_hoy(api, limpieza, hora=9)
    segunda = cita_hoy(api, limpieza, hora=10, celular="987111333")
    reloj.ahora = AHORA.replace(hour=9, minute=2)
    api.post(f"/citas/{primera}/iniciar")
    reloj.ahora = AHORA.replace(hour=9, minute=42)
    api.post(f"/citas/{primera}/terminar")
    reloj.ahora = AHORA.replace(hour=10, minute=30)
    api.post(f"/citas/{segunda}/no-asistio")
    actual = api.get("/metricas", anio=2026, mes=11).json()["actual"]
    assert actual["atendidas"] == 1 and actual["no_vinieron"] == 1
    assert actual["inasistencia_pct"] == 50.0
    assert actual["duracion_real_mediana_min"] == 40
    assert actual["inicio_tarde_mediana_min"] == 2
    assert actual["duracion_por_servicio"][0]["real_min"] == 40
