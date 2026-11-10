"""Sitio por subdominio (RF-01 a RF-04, RNF-02), tareas programadas (CU-12), push y privacidad."""
from datetime import timedelta
from pathlib import Path
from unittest import mock

import pytest
from django.conf import settings
from django.contrib.admin.sites import site
from django.core.exceptions import ValidationError
from django.core.management import call_command, base
from django.test import Client, override_settings
from django_q.models import Schedule

from agenda.models import Tratamiento
from citas import servicios
from citas.models import Cita, Estado, EventoCita, IntentoReserva, Paciente
from consultorios.models import Consultorio, Dispositivo, SesionRenovacion, Usuario
from denticita.checks import secretos_de_produccion
from mensajeria import push, tareas
from mensajeria.models import MensajeEntrante
from sitio.middleware import slug_desde_host
from .conftest import AHORA, reservar

pytestmark = pytest.mark.django_db
HOST = "sonrisa.denticita.test"


def sitio(ruta="/", host=HOST):
    return Client().get(ruta, headers={"host": host})


def test_subdominio_muestra_el_consultorio(consultorio, limpieza):
    r = sitio()
    assert r.status_code == 200
    html = r.content.decode()
    assert "Dra. Prueba" in html and "Limpieza" in html and "S/ 80" in html
    assert "Jr. Prueba 1" in html
    assert "wa.me/51911111111" in html
    assert "Reservar cita" in html


def test_subdominio_inexistente_da_404(db):
    assert sitio(host="nadie.denticita.test").status_code == 404


def test_dominio_raiz_muestra_la_plataforma(db):
    r = sitio(host="denticita.test")
    assert r.status_code == 200
    assert "RyCitas" in r.content.decode()


def test_el_sitio_se_cachea_5_min_y_la_disponibilidad_no(consultorio, limpieza):
    assert "s-maxage=300" in sitio()["Cache-Control"]
    disponibilidad = Client().get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"})
    assert "s-maxage" not in disponibilidad.get("Cache-Control", "")


def test_mi_cita_no_se_cachea(cliente, limpieza):
    token = reservar(cliente).json()["token"]
    r = sitio(f"/cita/{token}/")
    assert r.status_code == 200
    assert "no-store" in r["Cache-Control"] or "no-cache" in r["Cache-Control"]


def test_el_panel_no_se_expone_en_los_subdominios(consultorio):
    assert sitio("/admin/", host=HOST).status_code == 404
    assert sitio("/admin/login/", host="denticita.test").status_code == 200


def test_escapa_el_contenido_del_consultorio(consultorio):
    consultorio.presentacion = "<script>alert(1)</script>"
    consultorio.save()
    html = sitio().content.decode()
    assert "<script>alert(1)" not in html


def test_la_configuracion_embebida_no_permite_romper_el_script(consultorio):
    Tratamiento.objects.create(consultorio=consultorio, nombre="</script><script>alert(1)</script>", duracion_min=30)
    assert "</script><script>alert(1)" not in sitio().content.decode()


@pytest.mark.parametrize(
    "host,esperado",
    [
        ("sonrisa.denticita.test", "sonrisa"),
        ("SONRISA.denticita.test:8000", "sonrisa"),
        ("denticita.test", None),
        ("www.denticita.test", None),
        ("admin.denticita.test", None),
        ("a.b.denticita.test", None),
        ("sonrisa.otro.test", None),
        ("xdenticita.test", None),
    ],
)
def test_lectura_del_subdominio(host, esperado):
    assert slug_desde_host(host) == esperado


@pytest.mark.parametrize("slug", sorted(settings.SUBDOMINIOS_RESERVADOS))
def test_no_se_puede_registrar_un_subdominio_reservado(slug):
    c = Consultorio(slug=slug, nombre="X", doctor_nombre="X", direccion="X", whatsapp="51911111111")
    with pytest.raises(ValidationError):
        c.full_clean()


def test_presupuesto_de_peso_del_sitio(consultorio, limpieza):
    """RNF-02: HTML + CSS + JS < 150 KB sin imágenes (sin contar gzip, que lo reduce más)."""
    html = len(sitio().content)
    carpeta = Path(settings.BASE_DIR) / "sitio" / "static" / "sitio"
    recursos = sum(f.stat().st_size for f in carpeta.iterdir())
    assert html + recursos < 150 * 1024


def test_salud(db):
    assert Client().get("/salud/").json() == {"estado": "ok", "cola": "sin_programar"}


def test_salud_informa_si_la_cola_de_tareas_se_atrasa(db, reloj):
    """PRD-04: el qcluster caído no se nota en la web; un monitor con ?cola=1 sí lo ve."""
    from django.core.management import call_command
    from django.core.management.base import CommandError
    from django_q.models import Schedule

    from .conftest import AHORA

    Schedule.objects.create(name="expirar-prerreservas", func="x", schedule_type=Schedule.MINUTES, minutes=1,
                            next_run=AHORA + timedelta(minutes=1))
    assert Client().get("/salud/?cola=1").json() == {"estado": "ok", "cola": "ok"}
    call_command("salud_cola")
    reloj.avanzar(minutes=10)  # nadie adelantó next_run: el qcluster no está corriendo
    assert Client().get("/salud/").status_code == 200  # la web sigue sana
    r = Client().get("/salud/?cola=1")
    assert r.status_code == 503 and r.json()["cola"] == "atrasada"
    with pytest.raises(CommandError):
        call_command("salud_cola")


def test_salud_avisa_si_la_base_no_responde(db):
    with mock.patch("sitio.views.connection.cursor", side_effect=Exception):
        assert Client().get("/salud/").status_code == 503


def test_el_simulador_de_whatsapp_no_existe_en_produccion(cliente, limpieza):
    token = reservar(cliente).json()["token"]
    assert Client().post(f"/dev/simular-whatsapp/{token}/").status_code == 404


def test_documentacion_de_la_api_no_se_publica_en_produccion(db):
    # Las URLs se resuelven con settings_test (DEBUG=False): /docs no debe existir.
    assert Client().get("/api/v1/docs").status_code == 404


def test_panel_tiene_registrados_los_modelos_de_alta():
    assert Consultorio in site._registry and Usuario in site._registry and Paciente in site._registry


PRODUCCION = {
    "SECRET_KEY": "s" * 50, "JWT_SECRET": "j" * 50, "TURNSTILE_SECRET": "x", "TURNSTILE_SITE_KEY": "x",
    "FIREBASE_PROJECT_ID": "rycitas", "FIREBASE_CREDENCIALES": "/secretos/firebase.json",
    "PLATAFORMA_DOMINIO": "ryjec.com", "VERIFICAR_CLIENTES": True, "EMAIL_HOST": "smtp.ejemplo.pe",
    "TITULAR_NOMBRE": "RYJEC S.A.C.", "TITULAR_DOCUMENTO": "RUC 20000000001", "TITULAR_DOMICILIO": "Ayacucho",
    "TITULAR_CORREO": "datos@ryjec.com",
}


def test_chequeo_de_despliegue_pasa_con_la_configuracion_completa():
    with override_settings(**PRODUCCION):
        assert secretos_de_produccion(None) == []


def test_chequeo_de_despliegue_exige_los_secretos():
    with override_settings(**{**PRODUCCION, "TURNSTILE_SECRET": ""}):
        errores = secretos_de_produccion(None)
    assert [e.msg for e in errores] == ["Falta configurar TURNSTILE_SECRET en el entorno"]


@pytest.mark.parametrize(
    "cambio, codigo",
    [
        ({"JWT_SECRET": "s" * 50}, "denticita.E002"),  # igual a SECRET_KEY
        ({"JWT_SECRET": "corta"}, "denticita.E003"),
        ({"PLATAFORMA_DOMINIO": "localhost"}, "denticita.E004"),
        ({"EMAIL_HOST": "localhost"}, "denticita.E005"),
        ({"FIREBASE_PROJECT_ID": ""}, "denticita.E001"),
    ],
)
def test_check_deploy_exige_jwt_secret_propio_y_dominio_real(cambio, codigo):
    with override_settings(**{**PRODUCCION, **cambio}):
        assert [e.id for e in secretos_de_produccion(None)] == [codigo]


# --- Tareas -----------------------------------------------------------------------------------


@pytest.mark.verificacion_whatsapp
def test_a_los_15_min_la_prerreserva_expira_y_deja_auditoria(cliente, reloj, limpieza):
    reservar(cliente)
    assert tareas.expirar_prerreservas() == 0
    reloj.avanzar(minutes=15)
    assert tareas.expirar_prerreservas() == 1
    cita = Cita.objects.get()
    assert cita.estado == Estado.EXPIRADA
    assert EventoCita.objects.filter(cita=cita, valor_nuevo=Estado.EXPIRADA).exists()
    assert tareas.expirar_prerreservas() == 0


def test_expirar_no_toca_las_citas_confirmadas(api, reloj, limpieza):
    api.post("/citas", {"tratamiento_id": limpieza.pk, "inicio": AHORA.replace(hour=10).isoformat(), "nombre": "Ana", "celular": "987111444"})
    reloj.avanzar(hours=1)
    tareas.expirar_prerreservas()
    assert Cita.objects.get().estado == Estado.PROGRAMADA


def test_resumen_diario_indica_numero_y_primera_hora(api, sin_push_real, limpieza):
    manana = AHORA + timedelta(days=1)
    for hora, celular in ((11, "987111444"), (9, "987111555")):
        api.post("/citas", {"tratamiento_id": limpieza.pk, "inicio": manana.replace(hour=hora).isoformat(), "nombre": "Ana", "celular": celular})
    sin_push_real.reset_mock()
    assert tareas.resumen_diario() == 1
    assert sin_push_real.call_args.args[2:4] == ("Agenda de mañana", "2 citas. La primera a las 9:00 a. m. Toca para enviar los recordatorios.")


def test_resumen_no_molesta_si_no_hay_citas(consultorio, sin_push_real):
    assert tareas.resumen_diario() == 0
    sin_push_real.assert_not_called()


def test_limpieza_borra_solo_lo_vencido(consultorio, doctor, reloj):
    viejo = MensajeEntrante.objects.create(wamid="v", celular="51")
    IntentoReserva.objects.create(ip_hash="v")
    SesionRenovacion.objects.create(usuario=doctor, familia="00000000-0000-0000-0000-000000000000", token_hash="v", expira_en=reloj.ahora + timedelta(days=1))
    reloj.avanzar(days=91)
    nuevo = MensajeEntrante.objects.create(wamid="n", celular="51")
    tareas.limpieza_diaria()
    assert list(MensajeEntrante.objects.all()) == [nuevo]
    assert not MensajeEntrante.objects.filter(pk=viejo.pk).exists()
    assert not IntentoReserva.objects.exists() and not SesionRenovacion.objects.exists()


def test_programar_tareas_es_idempotente_y_no_adelanta_el_resumen(db):
    call_command("programar_tareas", verbosity=0, stdout=mock.Mock())
    primera = Schedule.objects.get(name="resumen-diario").next_run
    assert primera.astimezone(AHORA.tzinfo).hour == 20
    call_command("programar_tareas", stdout=mock.Mock())
    assert Schedule.objects.count() == 6
    assert Schedule.objects.get(name="resumen-diario").next_run == primera


def test_crear_demo_se_niega_fuera_de_desarrollo(db):
    with pytest.raises(base.CommandError):
        call_command("crear_demo", stdout=mock.Mock())


# --- Push -------------------------------------------------------------------------------------


def _dispositivo(doctor, token="t1"):
    return Dispositivo.objects.create(usuario=doctor, token_fcm=token)


def test_push_sin_firebase_se_omite_sin_error(doctor, consultorio):
    _dispositivo(doctor)
    assert push.enviar_a_consultorio(consultorio.pk, "t", "c", {}) == 0


@override_settings(FIREBASE_PROJECT_ID="p", FIREBASE_CREDENCIALES="c.json")
def test_push_llega_solo_a_los_dispositivos_del_consultorio(doctor, consultorio, otro_consultorio):
    _dispositivo(doctor, "mio")
    ajeno = Usuario.objects.create_user("x@x.test", "clave-segura-123", consultorio=otro_consultorio)
    _dispositivo(ajeno, "ajeno")
    sesion = mock.Mock()
    sesion.post.return_value.status_code = 200
    sesion.post.return_value.ok = True
    with mock.patch.object(push, "_sesion_fcm", return_value=sesion):
        assert push.enviar_a_consultorio(consultorio.pk, "Nueva cita", "Rosa", {"cita_id": 5}) == 1
    url = sesion.post.call_args.args[0]
    enviado = sesion.post.call_args.kwargs["json"]["message"]
    assert url == "https://fcm.googleapis.com/v1/projects/p/messages:send"
    assert enviado["token"] == "mio"
    assert enviado["data"] == {"cita_id": "5"}
    assert enviado["android"]["priority"] == "HIGH"


@override_settings(FIREBASE_PROJECT_ID="p", FIREBASE_CREDENCIALES="c.json")
def test_token_dado_de_baja_se_borra(doctor, consultorio):
    _dispositivo(doctor)
    sesion = mock.Mock()
    sesion.post.return_value.status_code = 404
    sesion.post.return_value.ok = False
    sesion.post.return_value.text = '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}'
    with mock.patch.object(push, "_sesion_fcm", return_value=sesion):
        assert push.enviar_a_consultorio(consultorio.pk, "t", "c", {}) == 0
    assert not Dispositivo.objects.exists()


# --- Privacidad -------------------------------------------------------------------------------


def test_borrado_a_pedido_quita_los_datos_personales(cliente, limpieza):
    reservar(cliente, inicio=AHORA + timedelta(days=1, hours=2))
    cita = Cita.objects.get()
    servicios.confirmar_por_whatsapp("+51987654321", cita.codigo)
    MensajeEntrante.objects.create(wamid="m", celular="51987654321", texto=cita.codigo)
    paciente = Paciente.objects.get()
    servicios.anonimizar_paciente(paciente)
    paciente.refresh_from_db()
    assert paciente.nombre == "Paciente eliminado"
    assert "987654321" not in paciente.celular
    assert not MensajeEntrante.objects.exists()
    cita.refresh_from_db()
    assert cita.nombre_ingresado == ""


def test_el_paciente_anonimizado_puede_volver_a_reservar(cliente, limpieza):
    reservar(cliente, inicio=AHORA.replace(hour=10))
    servicios.anonimizar_paciente(Paciente.objects.get())
    assert reservar(cliente, inicio=AHORA.replace(hour=12)).status_code == 201
    assert Paciente.objects.count() == 2



def test_sentry_no_recibe_datos_personales():
    """SEG-14/DAT-08: ni el cuerpo (nombre, celular), ni cookies, ni el token de gestión de la URL."""
    from denticita.errores import sin_datos_personales

    evento = {
        "request": {
            "url": "https://sonrisa.ryjec.com/c/AbC123token/?v=1", "data": {"nombre": "Rosa", "celular": "+51987"},
            "cookies": {"sessionid": "x"}, "headers": {"Authorization": "Bearer y"}, "query_string": "v=1",
        },
        "user": {"ip_address": "200.1.1.1"},
    }
    limpio = sin_datos_personales(evento, {})
    assert limpio["request"] == {"url": "https://sonrisa.ryjec.com/c/***/"}
    assert "user" not in limpio
