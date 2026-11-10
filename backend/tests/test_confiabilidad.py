"""Mejoras de confiabilidad del análisis RYJEC: idempotencia, outbox de avisos y recordatorio de pendientes."""
from datetime import timedelta
from unittest import mock

import pytest
from django.core.management import call_command

from citas.models import Cita, ClaveIdempotencia, Estado
from consultorios.models import Dispositivo, Profesional, Usuario
from mensajeria import push, tareas
from mensajeria.models import AvisoPendiente
from .conftest import AHORA, reservar

pytestmark = pytest.mark.django_db


def _post(cliente, ruta, datos, clave):
    return cliente.post(ruta, datos, content_type="application/json", headers={"Idempotency-Key": clave})


def _cuerpo_reserva(**extra):
    return {"motivo": "limpieza", "inicio": AHORA.replace(hour=11).isoformat(), "nombre": "Rosa Paz",
            "celular": "+51987654321", "acepta_politica": True, **extra}


# --- Idempotencia ---------------------------------------------------------------------------------


def test_reintento_de_reserva_no_duplica(cliente, limpieza):
    primera = _post(cliente, "/public/v1/sonrisa/reservas", _cuerpo_reserva(), "k-1")
    segunda = _post(cliente, "/public/v1/sonrisa/reservas", _cuerpo_reserva(), "k-1")
    assert primera.status_code == segunda.status_code == 201
    assert primera.json() == segunda.json()
    assert Cita.objects.count() == 1


def test_misma_clave_con_otro_cuerpo_se_rechaza(cliente, limpieza):
    _post(cliente, "/public/v1/sonrisa/reservas", _cuerpo_reserva(), "k-2")
    r = _post(cliente, "/public/v1/sonrisa/reservas", _cuerpo_reserva(nombre="Otra"), "k-2")
    assert r.status_code == 422 and r.json()["codigo"] == "clave_reutilizada"


def test_un_error_deja_reintentar_con_la_misma_clave(cliente, limpieza):
    malo = _post(cliente, "/public/v1/sonrisa/reservas", _cuerpo_reserva(motivo="nada"), "k-3")
    assert malo.status_code == 422
    assert not ClaveIdempotencia.objects.exists()


def test_sin_clave_funciona_igual(cliente, limpieza):
    assert reservar(cliente).status_code == 201


def test_doble_aprobar_responde_lo_mismo(api, cliente, limpieza):
    reservar(cliente)
    cita = Cita.objects.get()
    ruta = f"/api/v1/citas/{cita.pk}/aprobar"
    a = _post(api.c, ruta, {}, "ap-1")
    b = _post(api.c, ruta, {}, "ap-1")
    assert a.status_code == b.status_code == 200 and a.json() == b.json()
    assert cita.eventos.filter(tipo="estado", valor_nuevo=Estado.PROGRAMADA).count() == 1


def test_la_clave_es_por_cuenta(api, cliente, limpieza, consultorio):
    reservar(cliente)
    cita = Cita.objects.get()
    _post(api.c, f"/api/v1/citas/{cita.pk}/aprobar", {}, "comun")
    assert ClaveIdempotencia.objects.get().alcance.startswith("u")


# --- Outbox de avisos -----------------------------------------------------------------------------


def test_un_aviso_con_la_misma_clave_sale_una_vez(consultorio, sin_push_real):
    assert push.encolar(consultorio.pk, "T", "C", {"a": 1}, clave="x:1") is True
    assert push.encolar(consultorio.pk, "T", "C", {"a": 1}, clave="x:1") is False
    assert AvisoPendiente.objects.count() == 1 and sin_push_real.call_count == 1


def test_la_reserva_deja_su_aviso_en_la_tabla(cliente, limpieza, django_capture_on_commit_callbacks):
    with django_capture_on_commit_callbacks(execute=True):
        reservar(cliente)
    aviso = AvisoPendiente.objects.get()
    cita = Cita.objects.get()
    assert aviso.clave == f"por_aprobar:{cita.pk}" and aviso.profesional_id == cita.profesional_id


@pytest.fixture
def firebase(settings):
    settings.FIREBASE_PROJECT_ID = "demo"
    settings.FIREBASE_CREDENCIALES = "/no/existe.json"
    sesion = mock.Mock()
    with mock.patch("mensajeria.push._sesion_fcm", return_value=sesion):
        yield sesion


def test_sin_red_se_reintenta_y_luego_sale(consultorio, doctor, firebase, reloj):
    Dispositivo.objects.create(usuario=doctor, token_fcm="tok-1")
    push.encolar(consultorio.pk, "T", "C", clave="r:1")
    aviso = AvisoPendiente.objects.get()
    firebase.post.side_effect = ConnectionError()
    push.enviar_a_consultorio(consultorio.pk, "T", "C", {}, aviso.pk)
    aviso.refresh_from_db()
    assert aviso.enviado_en is None and aviso.intentos == 1
    assert aviso.proximo_intento == reloj.ahora + timedelta(minutes=1)

    assert push.reintentar_pendientes() == 0  # todavía no le toca
    reloj.avanzar(minutes=2)
    firebase.post.side_effect = None
    firebase.post.return_value = mock.Mock(ok=True, status_code=200, text="")
    assert push.reintentar_pendientes() == 1
    aviso.refresh_from_db()
    assert aviso.enviado_en is not None and aviso.intentos == 2


def test_tras_cuatro_reintentos_se_abandona(consultorio, doctor, firebase, reloj):
    Dispositivo.objects.create(usuario=doctor, token_fcm="tok-1")
    push.encolar(consultorio.pk, "T", "C", clave="r:2")
    aviso = AvisoPendiente.objects.get()
    firebase.post.side_effect = ConnectionError()
    for _ in range(5):
        push.enviar_a_consultorio(consultorio.pk, "T", "C", {}, aviso.pk)
    aviso.refresh_from_db()
    assert aviso.intentos == 5 and aviso.enviado_en is not None and aviso.error.startswith("red")


def test_el_aviso_va_al_profesional_y_a_los_encargados(consultorio, doctor, firebase):
    otro = Profesional.objects.create(consultorio=consultorio, nombre="Dr. Otro")
    principal = consultorio.profesional_principal()
    cuenta_principal = Usuario.objects.create_user("p@sonrisa.test", "clave-segura-123", consultorio=consultorio,
                                                   profesional=principal)
    cuenta_otro = Usuario.objects.create_user("o@sonrisa.test", "clave-segura-123", consultorio=consultorio,
                                              profesional=otro)
    Dispositivo.objects.create(usuario=doctor, token_fcm="encargado")  # sin profesional: ve todo
    Dispositivo.objects.create(usuario=cuenta_principal, token_fcm="principal")
    Dispositivo.objects.create(usuario=cuenta_otro, token_fcm="otro")
    firebase.post.return_value = mock.Mock(ok=True, status_code=200, text="")
    push.encolar(consultorio.pk, "T", "C", clave="d:1", profesional_id=principal.pk)
    push.enviar_a_consultorio(consultorio.pk, "T", "C", {}, AvisoPendiente.objects.get().pk)
    tokens = {llamada.kwargs["json"]["message"]["token"] for llamada in firebase.post.call_args_list}
    assert tokens == {"encargado", "principal"}


def test_sin_firebase_el_aviso_se_cierra(consultorio):
    push.encolar(consultorio.pk, "T", "C", clave="f:1")
    aviso = AvisoPendiente.objects.get()
    assert push.enviar_a_consultorio(consultorio.pk, "T", "C", {}, aviso.pk) == 0
    aviso.refresh_from_db()
    assert aviso.enviado_en is not None


# --- Recordar pendientes --------------------------------------------------------------------------


def test_recuerda_reservas_sin_respuesta(cliente, limpieza, consultorio, reloj):
    reservar(cliente, inicio=AHORA.replace(hour=11) + timedelta(days=3))
    assert tareas.recordar_pendientes() == 0  # recién llegó
    reloj.avanzar(hours=2, minutes=5)
    assert tareas.recordar_pendientes() == 1
    assert "1 reserva espera" in AvisoPendiente.objects.get(clave__startswith="pendientes").cuerpo
    assert tareas.recordar_pendientes() == 0  # no se repite en la misma hora


def test_recuerda_la_vispera_aunque_sea_reciente(cliente, limpieza, consultorio):
    reservar(cliente, inicio=AHORA.replace(hour=11) + timedelta(days=1))
    assert tareas.recordar_pendientes() == 1


def test_negocio_suspendido_no_recibe_recordatorios(cliente, limpieza, consultorio):
    reservar(cliente, inicio=AHORA.replace(hour=11) + timedelta(days=1))
    consultorio.suspendido = True
    consultorio.save()
    assert tareas.recordar_pendientes() == 0


def test_las_tareas_nuevas_quedan_programadas():
    from django_q.models import Schedule

    call_command("programar_tareas", stdout=mock.Mock())
    nombres = set(Schedule.objects.values_list("name", flat=True))
    assert {"reintentar-avisos", "recordar-pendientes"} <= nombres


# --- Impacto de un horario nuevo ------------------------------------------------------------------


def _tramos(*dias, inicio="09:00", fin="13:00"):
    return {"tramos": [{"dia_semana": d, "hora_inicio": inicio, "hora_fin": fin} for d in dias]}


def test_impacto_lista_las_citas_que_quedan_fuera(api, cliente, limpieza):
    reservar(cliente)  # lunes 11:00
    reservar(cliente, inicio=AHORA.replace(hour=11) + timedelta(days=1), celular="+51987000002")  # martes
    r = api.post("/horario/impacto", _tramos(1, 2, 3, 4, 5))  # deja de atender los lunes
    citas = r.json()["citas"]
    assert r.status_code == 200 and len(citas) == 1
    assert "Cambiamos nuestro horario" in citas[0]["whatsapp_url"].replace("%20", " ")
    assert Cita.objects.filter(estado=Estado.POR_APROBAR).count() == 2  # nada se cancela solo


def test_impacto_por_hora(api, cliente, limpieza):
    reservar(cliente)  # 11:00 a 11:30
    assert len(api.post("/horario/impacto", _tramos(0, fin="11:15")).json()["citas"]) == 1
    assert api.post("/horario/impacto", _tramos(0, fin="11:30")).json()["citas"] == []


def test_guardar_horario_no_borra_el_de_cada_profesional(api, consultorio):
    from agenda.models import HorarioSemanal
    from datetime import time

    otro = Profesional.objects.create(consultorio=consultorio, nombre="Dr. Otro")
    HorarioSemanal.objects.create(consultorio=consultorio, profesional=otro, dia_semana=5, hora_inicio=time(8),
                                  hora_fin=time(12))
    api.put("/horario", _tramos(0))
    assert HorarioSemanal.objects.filter(profesional=otro).count() == 1
    assert len(api.get("/horario").json()["tramos"]) == 1


# --- Métricas, sesiones y auditoría ---------------------------------------------------------------


def test_metricas_del_mes(api, cliente, limpieza):
    reservar(cliente)
    datos = api.get("/metricas", anio=2026, mes=11).json()
    assert datos["actual"]["citas"] == 1 and datos["actual"]["por_confirmar"] == 1
    assert datos["anterior"]["citas"] == 0
    assert api.get("/metricas", anio=2026, mes=13).status_code == 422


def test_cerrar_todas_las_sesiones(api, doctor):
    from consultorios.autenticacion import tokens
    from consultorios.models import SesionRenovacion

    tokens(doctor)
    tokens(doctor)
    Dispositivo.objects.create(usuario=doctor, token_fcm="tok")
    r = api.post("/auth/cerrar-todas")
    assert r.status_code == 200 and r.json()["sesiones_cerradas"] == 2
    assert not SesionRenovacion.objects.filter(usuario=doctor, revocado=False).exists()
    assert not Dispositivo.objects.exists()


def test_cada_evento_guarda_origen_y_peticion(api, cliente, limpieza):
    r = reservar(cliente)
    assert r["X-Request-ID"]
    cita = Cita.objects.get()
    evento = cita.eventos.get()
    assert (evento.origen, evento.request_id) == ("sitio", r["X-Request-ID"])
    api.c.post(f"/api/v1/citas/{cita.pk}/aprobar", {}, content_type="application/json",
               headers={"X-Request-ID": "abc12345-0000"})
    ultimo = cita.eventos.order_by("-pk").first()
    assert (ultimo.origen, ultimo.request_id) == ("app", "abc12345-0000")


def test_las_tareas_quedan_como_sistema(cliente, limpieza, reloj):
    reservar(cliente)
    reloj.avanzar(days=1)
    tareas.expirar_prerreservas()
    from citas.models import EventoCita

    assert not EventoCita.objects.filter(origen="").exists()
