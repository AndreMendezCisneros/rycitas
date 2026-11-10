"""Sin API de WhatsApp: el doctor confirma, recuerda y avisa desde su propio WhatsApp con un toque (costo cero)."""
from datetime import timedelta
from urllib.parse import parse_qs, urlparse

import pytest

from citas.models import Cita, Estado, EventoCita
from mensajeria import tareas
from .conftest import AHORA, reservar

pytestmark = pytest.mark.django_db


def texto_de(url: str) -> str:
    return parse_qs(urlparse(url).query)["text"][0]


def numero_de(url: str) -> str:
    return urlparse(url).path.strip("/")


def cita_doctor(api, limpieza, hora=10, celular="987111222", nombre="Luis Mamani", dia=0):
    inicio = (AHORA + timedelta(days=dia)).replace(hour=hora)
    r = api.post("/citas", {"tratamiento_id": limpieza.pk, "inicio": inicio.isoformat(), "nombre": nombre, "celular": celular})
    assert r.status_code == 201, r.content
    return r.json()["cita_id"]


# --- La reserva web queda por confirmar -----------------------------------------------------------


def test_la_reserva_web_queda_por_confirmar_sin_codigo_ni_vencimiento(cliente, limpieza):
    r = reservar(cliente)
    assert r.status_code == 201, r.content
    datos = r.json()
    assert datos["estado"] == Estado.POR_APROBAR
    assert datos["codigo"] is None and datos["whatsapp_url"] is None
    cita = Cita.objects.get()
    assert cita.estado == Estado.POR_APROBAR and cita.codigo == "" and cita.expira_en is None
    assert EventoCita.objects.filter(cita=cita, valor_nuevo=Estado.POR_APROBAR).exists()


def test_avisa_al_doctor_por_push(cliente, limpieza, django_capture_on_commit_callbacks, sin_push_real):
    with django_capture_on_commit_callbacks(execute=True):
        reservar(cliente)
    titulos = [llamada.args[2] for llamada in sin_push_real.call_args_list]
    assert "Nueva reserva por confirmar" in titulos


def test_retiene_el_horario_hasta_su_hora_aunque_nadie_confirme(cliente, reloj, limpieza):
    reservar(cliente)
    reloj.avanzar(hours=2)  # 10:00: ya no hay vencimiento a los 15 min
    tareas.expirar_prerreservas()
    assert Cita.objects.get().estado == Estado.POR_APROBAR
    otro = reservar(cliente, celular="+51987000111")
    assert otro.status_code == 409
    reloj.avanzar(hours=1, minutes=1)  # pasó las 11:00
    tareas.expirar_prerreservas()
    assert Cita.objects.get().estado == Estado.EXPIRADA


def test_la_agenda_muestra_las_reservas_por_confirmar(api, cliente, limpieza):
    reservar(cliente)
    datos = api.get("/agenda").json()
    assert datos["por_aprobar"] == 1
    assert [c["estado"] for c in datos["citas"]] == [Estado.POR_APROBAR]
    assert len(api.get("/citas/por-aprobar").json()["citas"]) == 1


def test_sin_verificacion_el_webhook_y_el_simulador_no_existen(cliente, limpieza):
    assert cliente.get("/webhooks/whatsapp", {"hub.mode": "subscribe"}).status_code == 404
    assert cliente.post("/webhooks/whatsapp", "{}", content_type="application/json").status_code == 404
    token = reservar(cliente).json()["token"]
    assert cliente.post(f"/public/v1/citas/{token}/sin-whatsapp").status_code == 404


def test_check_de_despliegue_no_pide_secretos_de_meta(settings):
    from denticita.checks import secretos_de_produccion

    settings.DEBUG = False
    settings.WHATSAPP_APP_SECRET = settings.WHATSAPP_VERIFY_TOKEN = ""
    mensajes = [e.msg for e in secretos_de_produccion(None)]
    assert not any("WHATSAPP" in m for m in mensajes)


# --- Confirmar o rechazar con el mensaje ya escrito ----------------------------------------------


def test_confirmar_abre_whatsapp_del_paciente_con_el_mensaje_del_tratamiento(api, cliente, limpieza):
    limpieza.indicaciones = "Ven 10 min antes."
    limpieza.save()
    token = reservar(cliente).json()["token"]
    cita = Cita.objects.get()
    r = api.post(f"/citas/{cita.pk}/aprobar")
    assert r.status_code == 200, r.content
    datos = r.json()
    assert datos["estado"] == Estado.PROGRAMADA
    assert numero_de(datos["whatsapp_url"]) == "51987654321"
    texto = texto_de(datos["whatsapp_url"])
    assert texto.startswith("Hola Rosa, te escribe Dra. Prueba de Sonrisa.")
    assert "Tu cita de Limpieza quedó confirmada para hoy a las 11:00 a. m." in texto
    assert "Ven 10 min antes." in texto
    assert f"/c/{token}/" in texto
    assert cliente.get(f"/public/v1/citas/{token}").json()["estado"] == Estado.PROGRAMADA


def test_fecha_del_mensaje_en_palabras(api, cliente, limpieza):
    reservar(cliente, inicio=(AHORA + timedelta(days=3)).replace(hour=12, minute=30))
    cita = Cita.objects.get()
    texto = texto_de(api.post(f"/citas/{cita.pk}/aprobar").json()["whatsapp_url"])
    assert "el jueves 12 de nov a las 12:30 p. m." in texto
    reservar(cliente, inicio=(AHORA + timedelta(days=1)).replace(hour=9), celular="+51987000222", nombre="Ana")
    otra = Cita.objects.get(nombre_ingresado="Ana")
    assert "mañana a las 9:00 a. m." in texto_de(api.post(f"/citas/{otra.pk}/aprobar").json()["whatsapp_url"])


def test_rechazar_libera_el_horario_y_ofrece_otro(api, cliente, limpieza):
    reservar(cliente)
    cita = Cita.objects.get()
    datos = api.post(f"/citas/{cita.pk}/rechazar").json()
    texto = texto_de(datos["whatsapp_url"])
    assert "no podremos atenderte hoy a las 11:00 a. m." in texto
    assert texto.endswith("/#reservar")
    assert reservar(cliente, celular="+51987000111").status_code == 201


def test_mover_avisa_la_nueva_hora(api, limpieza):
    cita = cita_doctor(api, limpieza, hora=10)
    datos = api.post(f"/citas/{cita}/reprogramar", {"inicio": AHORA.replace(hour=12).isoformat()}).json()
    assert "se movió para hoy a las 12:00 p. m." in texto_de(datos["whatsapp_url"])


def test_indicaciones_se_editan_desde_la_app(api, limpieza):
    r = api.put(f"/tratamientos/{limpieza.pk}", {"nombre": "Limpieza", "duracion_min": 30, "indicaciones": "Trae tu radiografía."})
    assert r.status_code == 200, r.content
    assert r.json()["indicaciones"] == "Trae tu radiografía."


# --- Cancelar y avisar al siguiente ----------------------------------------------------------------


def test_cancelar_ofrece_avisar_a_los_siguientes_del_dia(api, limpieza):
    primera = cita_doctor(api, limpieza, hora=9, celular="987000001", nombre="Ana Ruiz")
    cita_doctor(api, limpieza, hora=10, celular="987000002", nombre="Beto Paz")
    cita_doctor(api, limpieza, hora=11, celular="987000003", nombre="Carla Soto")
    cita_doctor(api, limpieza, hora=10, celular="987000004", nombre="Dani Otro Día", dia=1)
    datos = api.post(f"/citas/{primera}/cancelar").json()
    assert "fue cancelada" in texto_de(datos["whatsapp_url"])
    assert numero_de(datos["whatsapp_url"]) == "51987000001"
    siguientes = datos["siguientes"]
    assert [s["paciente"] for s in siguientes] == ["Beto Paz", "Carla Soto"]
    texto = texto_de(siguientes[0]["whatsapp_url"])
    assert numero_de(siguientes[0]["whatsapp_url"]) == "51987000002"
    assert "Se liberó un espacio hoy a las 9:00 a. m." in texto
    assert "antes de tu cita de las 10:00 a. m." in texto


def test_no_vino_tambien_ofrece_a_los_siguientes(api, reloj, limpieza):
    primera = cita_doctor(api, limpieza, hora=9, celular="987000001")
    cita_doctor(api, limpieza, hora=11, celular="987000002", nombre="Beto Paz")
    reloj.avanzar(hours=1, minutes=15)  # 9:15
    datos = api.post(f"/citas/{primera}/no-asistio").json()
    assert [s["paciente"] for s in datos["siguientes"]] == ["Beto Paz"]
    assert "Se liberó un espacio hoy a las 9:15 a. m." in texto_de(datos["siguientes"][0]["whatsapp_url"])


def test_sin_siguientes_la_lista_va_vacia(api, limpieza):
    cita = cita_doctor(api, limpieza, hora=12)
    assert api.post(f"/citas/{cita}/cancelar").json()["siguientes"] == []


# --- Recordatorios ----------------------------------------------------------------------------------


def test_recordatorios_de_manana_con_su_mensaje(api, cliente, limpieza):
    manana = cita_doctor(api, limpieza, hora=9, celular="987000001", nombre="Ana Ruiz", dia=1)
    cita_doctor(api, limpieza, hora=10, celular="987000002", nombre="Hoy No")
    reservar(cliente, inicio=(AHORA + timedelta(days=1)).replace(hour=11))  # por confirmar: no se recuerda
    datos = api.get("/citas/recordatorios").json()
    assert datos["fecha"] == "2026-11-10"
    assert [c["id"] for c in datos["citas"]] == [manana]
    texto = texto_de(datos["citas"][0]["whatsapp_url"])
    assert "Te recordamos tu cita de Limpieza mañana a las 9:00 a. m." in texto
    assert "¿Nos confirmas tu asistencia?" in texto
    assert api.get("/citas/recordatorios", fecha="2026-11-09").json()["citas"][0]["paciente"]["nombre"] == "Hoy No"


def test_marcar_recordado_y_asistencia(api, limpieza):
    cita = cita_doctor(api, limpieza, hora=9, dia=1)
    r = api.post(f"/citas/{cita}/recordado")
    assert r.status_code == 200 and r.json()["recordatorio_enviado_en"].startswith("2026-11-09T08:00")
    assert api.post(f"/citas/{cita}/asistencia", {"confirmada": True}).json()["asistencia_confirmada"] is True
    assert api.post(f"/citas/{cita}/asistencia", {"confirmada": None}).json()["asistencia_confirmada"] is None
    fila = api.get("/citas/recordatorios").json()["citas"][0]
    assert fila["recordatorio_enviado_en"] is not None
    assert EventoCita.objects.filter(cita_id=cita, tipo="recordatorio").exists()


def test_asistencia_solo_en_citas_programadas(api, limpieza):
    cita = cita_doctor(api, limpieza, hora=9, dia=1)
    api.post(f"/citas/{cita}/cancelar")
    assert api.post(f"/citas/{cita}/asistencia", {"confirmada": True}).status_code == 409


def test_push_de_las_8_lleva_a_los_recordatorios(api, sin_push_real, limpieza):
    cita_doctor(api, limpieza, hora=9, dia=1)
    sin_push_real.reset_mock()
    assert tareas.resumen_diario() == 1
    assert sin_push_real.call_args.args[4] == {"tipo": "recordatorios"}


# --- Duración real y mes ----------------------------------------------------------------------------


def test_duracion_real_es_la_mediana_de_las_terminadas(api, reloj, limpieza):
    for minutos in (40, 50, 70):
        cita = cita_doctor(api, limpieza, hora=9)
        api.post(f"/citas/{cita}/iniciar")
        reloj.avanzar(minutes=minutos)
        api.post(f"/citas/{cita}/terminar")
        Cita.objects.filter(pk=cita).update(inicio=AHORA.replace(hour=9) - timedelta(days=30), fin=AHORA.replace(hour=9, minute=30) - timedelta(days=30), fin_ocupado=AHORA.replace(hour=9, minute=40) - timedelta(days=30))
        reloj.ahora = AHORA
    fila = next(t for t in api.get("/tratamientos").json()["tratamientos"] if t["id"] == limpieza.pk)
    assert fila["duracion_real_min"] == 50
    assert fila["duracion_real_citas"] == 3


def test_sin_historial_no_hay_duracion_real(api, limpieza):
    fila = api.get("/tratamientos").json()["tratamientos"][0]
    assert fila["duracion_real_min"] is None and fila["duracion_real_citas"] == 0


def test_vista_de_mes(api, cliente, limpieza):
    from agenda.models import Bloqueo

    cita_doctor(api, limpieza, hora=9)
    cita_doctor(api, limpieza, hora=10, celular="987000009")
    reservar(cliente, inicio=(AHORA + timedelta(days=2)).replace(hour=11))
    Bloqueo.objects.create(consultorio=limpieza.consultorio, inicio=AHORA + timedelta(days=5), fin=AHORA + timedelta(days=7), motivo="Congreso")
    datos = api.get("/agenda/mes", anio=2026, mes=11).json()
    dias = {d["fecha"]: d for d in datos["dias"]}
    assert len(datos["dias"]) == 30
    assert dias["2026-11-09"]["citas"] == 2
    assert dias["2026-11-11"] == {"fecha": "2026-11-11", "citas": 1, "por_confirmar": 1, "bloqueo": False}
    assert dias["2026-11-14"]["bloqueo"] and dias["2026-11-15"]["bloqueo"] and dias["2026-11-16"]["bloqueo"]
    assert not dias["2026-11-17"]["bloqueo"]
    assert api.get("/agenda/mes", anio=2026, mes=13).status_code == 422


# --- Enlace del paciente de solo lectura ----------------------------------------------------------


def test_el_enlace_muestra_el_estado_sin_opciones_de_cancelar(cliente, limpieza):
    token = reservar(cliente).json()["token"]
    datos = cliente.get(f"/public/v1/citas/{token}").json()
    assert datos["estado"] == Estado.POR_APROBAR
    assert "puede_cancelar" not in datos and "puede_reprogramar" not in datos
    assert cliente.post(f"/public/v1/citas/{token}/cancelar").status_code in (404, 405)


@pytest.mark.parametrize("indicaciones", ["", "Ven 10 min antes", "Ven 10 min antes."])
def test_los_mensajes_no_tienen_puntos_dobles(api, cliente, limpieza, indicaciones):
    limpieza.indicaciones = indicaciones
    limpieza.save()
    reservar(cliente)
    cita = Cita.objects.get()
    textos = [texto_de(api.post(f"/citas/{cita.pk}/aprobar").json()["whatsapp_url"])]
    textos.append(texto_de(api.post(f"/citas/{cita.pk}/reprogramar", {"inicio": AHORA.replace(hour=12).isoformat()}).json()["whatsapp_url"]))
    textos.append(texto_de(api.get("/citas/recordatorios", fecha="2026-11-09").json()["citas"][0]["whatsapp_url"]))
    cita_doctor(api, limpieza, hora=12, celular="987000077", nombre="Otra Paciente", dia=1)
    temprana = cita_doctor(api, limpieza, hora=9, celular="987000078", nombre="Temprana", dia=1)
    cancelada = api.post(f"/citas/{temprana}/cancelar").json()
    textos += [texto_de(cancelada["whatsapp_url"]), texto_de(cancelada["siguientes"][0]["whatsapp_url"])]
    for texto in textos:
        assert ".." not in texto, texto
        assert " ." not in texto, texto
    if indicaciones:
        assert all("Ven 10 min antes." in t for t in textos[:3])  # confirmar, mover y recordar
