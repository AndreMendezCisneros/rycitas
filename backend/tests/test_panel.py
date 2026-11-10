"""Panel de la plataforma: crear negocios desde su tipo y controlarlos (sitio, app, opciones y servicio)."""
import pytest
from django.test import Client

from agenda.models import HorarioSemanal, Tratamiento
from citas.models import Cita, Estado
from consultorios.models import Consultorio, SesionRenovacion, Usuario
from consultorios.autenticacion import tokens
from panel.models import EventoPanel
from .conftest import reservar

pytestmark = pytest.mark.django_db


@pytest.fixture
def staff(db):
    return Usuario.objects.create_user("equipo@plataforma.test", "clave-segura-123", is_staff=True)


@pytest.fixture
def panel(staff):
    c = Client()
    c.force_login(staff)
    return c


def _datos_barberia(**extra):
    datos = {
        "rubro": "barberia",
        "datos-nombre": "Barbería Wari", "datos-slug": "barberia-wari", "datos-whatsapp": "51911222333",
        "datos-direccion": "Jr. Lima 100", "datos-mapa_url": "", "datos-profesionales": "Juan\nPedro",
        "serv-TOTAL_FORMS": "3", "serv-INITIAL_FORMS": "0", "serv-MIN_NUM_FORMS": "0", "serv-MAX_NUM_FORMS": "1000",
        "serv-0-incluir": "on", "serv-0-nombre": "Corte clásico", "serv-0-motivo": "Corte", "serv-0-duracion_min": "30",
        "serv-0-margen_min": "5", "serv-0-precio": "20",
        "serv-1-incluir": "on", "serv-1-nombre": "Ondulado", "serv-1-duracion_min": "90", "serv-1-margen_min": "10",
        "serv-1-precio": "60",
        "serv-2-nombre": "No incluido", "serv-2-duracion_min": "10",
        "hor-d0_i1": "09:00", "hor-d0_f1": "13:00", "hor-d0_i2": "15:00", "hor-d0_f2": "20:00",
        "hor-d5_i1": "09:00", "hor-d5_f1": "20:00",
        "modo_agenda": "por_profesional", "elegir_profesional": "on", "precio_ofertable": "on",
        "llegar_antes_min": "5", "tolerancia_inasistencia_min": "10", "recordar_pendientes_horas": "2",
        "sesion_web_min": "30", "anticipacion_min_horas": "1", "dias_maximos": "21",
        "cuenta_correo": "juan@barberiawari.test",
    }
    return {**datos, **extra}


def test_sin_sesion_redirige_a_entrar(client):
    r = client.get("/panel/")
    assert r.status_code == 302 and r["Location"].startswith("/panel/entrar/")


def test_una_cuenta_de_negocio_no_entra_al_panel(doctor):
    c = Client()
    r = c.post("/panel/entrar/", {"username": "doc@sonrisa.test", "password": "clave-segura-123"})
    assert "no tiene acceso al panel" in r.content.decode()
    assert c.get("/panel/").status_code == 302


def test_el_equipo_entra_con_su_correo(staff):
    c = Client()
    r = c.post("/panel/entrar/", {"username": "equipo@plataforma.test", "password": "clave-segura-123"})
    assert r.status_code == 302 and r["Location"] == "/panel/"
    assert c.get("/panel/").status_code == 200


def test_el_panel_no_existe_en_el_subdominio_de_un_negocio(panel, consultorio):
    assert panel.get("/panel/", HTTP_HOST="sonrisa.denticita.test").status_code == 404


def test_la_sesion_del_panel_dura_una_hora(settings):
    assert settings.SESSION_COOKIE_AGE == 3600 and settings.SESSION_SAVE_EVERY_REQUEST


def test_lista_de_negocios(panel, consultorio):
    html = panel.get("/panel/").content.decode()
    assert "Sonrisa" in html and "Odontología" in html and "Publicado" in html


def test_elegir_tipo_precarga_sus_servicios(panel):
    assert "Barbería" in panel.get("/panel/nuevo/").content.decode()
    html = panel.get("/panel/nuevo/?tipo=barberia").content.decode()
    assert "Corte clásico" in html and "Ondulado / permanente" in html
    assert 'value="09:00"' in html


def test_crear_una_barberia_completa(panel, staff):
    r = panel.post("/panel/nuevo/", _datos_barberia())
    c = Consultorio.objects.get(slug="barberia-wari")
    assert r.status_code == 302 and r["Location"] == f"/panel/n/{c.pk}/"
    assert c.rubro == "barberia" and c.publicado is False
    assert [p.nombre for p in c.profesionales.order_by("orden")] == ["Juan", "Pedro"]
    assert list(Tratamiento.objects.filter(consultorio=c).values_list("nombre", flat=True)) == ["Corte clásico", "Ondulado"]
    assert HorarioSemanal.objects.filter(consultorio=c).count() == 3
    o = c.opciones_efectivas
    assert (o["modo_agenda"], o["precio_ofertable"], o["sesion_web_min"], o["llegar_antes_min"]) == ("por_profesional", True, 30, 5)
    assert c.reglas_efectivas["dias_maximos"] == 21
    cuenta = Usuario.objects.get(correo="juan@barberiawari.test")
    assert cuenta.consultorio == c
    seguimiento = panel.get(r["Location"])
    assert "contraseña:" in seguimiento.content.decode()
    assert EventoPanel.objects.filter(consultorio=c, accion="crear", usuario=staff).exists()


def test_no_se_repite_un_subdominio(panel, consultorio):
    r = panel.post("/panel/nuevo/", _datos_barberia(**{"datos-slug": "sonrisa"}))
    assert r.status_code == 200 and "ya está en uso" in r.content.decode()


def test_horario_invalido_se_explica(panel):
    r = panel.post("/panel/nuevo/", _datos_barberia(**{"hor-d0_i1": "14:00", "hor-d0_f1": "13:00"}))
    assert r.status_code == 200 and "debe ser antes del fin" in r.content.decode()
    assert not Consultorio.objects.filter(slug="barberia-wari").exists()


def test_publicar_y_suspender_sin_tocar_las_citas(panel, consultorio, limpieza, cliente):
    reservar(cliente)
    assert panel.post(f"/panel/n/{consultorio.pk}/accion/suspender/", {"motivo": "Falta de pago"}).status_code == 302
    consultorio.refresh_from_db()
    assert consultorio.suspendido and Cita.objects.get().estado == Estado.POR_APROBAR
    assert reservar(cliente, celular="+51987000001").status_code == 403
    panel.post(f"/panel/n/{consultorio.pk}/accion/reactivar/")
    consultorio.refresh_from_db()
    assert not consultorio.suspendido
    panel.post(f"/panel/n/{consultorio.pk}/accion/despublicar/")
    consultorio.refresh_from_db()
    assert not consultorio.publicado
    acciones = list(EventoPanel.objects.filter(consultorio=consultorio).values_list("accion", flat=True))
    assert {"suspender", "reactivar", "despublicar"} <= set(acciones)


def test_cuentas_de_la_app(panel, consultorio, doctor):
    r = panel.post(f"/panel/n/{consultorio.pk}/?p=equipo",
                   {"accion": "cuenta", "cuenta-correo": "asistente@sonrisa.test", "cuenta-nombre": "Asistente"})
    assert r.status_code == 302
    asistente = Usuario.objects.get(correo="asistente@sonrisa.test")
    assert asistente.consultorio == consultorio and asistente.profesional is None

    tokens(doctor)
    panel.post(f"/panel/n/{consultorio.pk}/cuenta/{doctor.pk}/cerrar-sesiones/")
    assert not SesionRenovacion.objects.filter(usuario=doctor, revocado=False).exists()

    anterior = doctor.password
    panel.post(f"/panel/n/{consultorio.pk}/cuenta/{doctor.pk}/contrasena/")
    doctor.refresh_from_db()
    assert doctor.password != anterior

    panel.post(f"/panel/n/{consultorio.pk}/cuenta/{doctor.pk}/desactivar/")
    doctor.refresh_from_db()
    assert doctor.activo is False


def test_no_se_toca_una_cuenta_de_otro_negocio(panel, consultorio, otro_consultorio, doctor):
    assert panel.post(f"/panel/n/{otro_consultorio.pk}/cuenta/{doctor.pk}/desactivar/").status_code == 404


def test_guardar_opciones(panel, consultorio):
    datos = {"modo_agenda": "compartida", "precio_ofertable": "on", "llegar_antes_min": "20",
             "tolerancia_inasistencia_min": "15", "recordar_pendientes_horas": "3", "sesion_web_min": "60",
             "anticipacion_min_horas": "2", "dias_maximos": "30", "adelantos": "on"}
    assert panel.post(f"/panel/n/{consultorio.pk}/?p=opciones", datos).status_code == 302
    consultorio.refresh_from_db()
    o = consultorio.opciones_efectivas
    assert o["precio_ofertable"] and o["llegar_antes_min"] == 20 and o["recordar_pendientes_horas"] == 3
    assert o["adelantos"] is False  # deshabilitado en la plataforma


def test_guardar_horario(panel, consultorio):
    r = panel.post(f"/panel/n/{consultorio.pk}/?p=horario", {"hor-d2_i1": "10:00", "hor-d2_f1": "12:00"})
    assert r.status_code == 302
    assert list(HorarioSemanal.objects.filter(consultorio=consultorio).values_list("dia_semana", flat=True)) == [2]


def test_exportar_citas_y_clientes(panel, consultorio, limpieza, cliente):
    reservar(cliente)
    citas = panel.get(f"/panel/n/{consultorio.pk}/exportar/citas.csv")
    assert citas["Content-Type"].startswith("text/csv")
    texto = citas.content.decode("utf-8-sig")
    assert "Limpieza" in texto and "Rosa Paz" in texto and "80.00" in texto
    assert "+51987654321" in panel.get(f"/panel/n/{consultorio.pk}/exportar/clientes.csv").content.decode("utf-8-sig")


@pytest.mark.parametrize("pestana", ["resumen", "sitio", "servicios", "horario", "equipo", "opciones", "servicio"])
def test_todas_las_pestanas_cargan(panel, consultorio, limpieza, pestana):
    r = panel.get(f"/panel/n/{consultorio.pk}/?p={pestana}")
    assert r.status_code == 200, pestana


def test_editar_profesionales_y_sus_servicios(panel, consultorio, limpieza):
    principal = consultorio.profesional_principal()
    datos = {
        "accion": "profesionales",
        "p-TOTAL_FORMS": "2", "p-INITIAL_FORMS": "1", "p-MIN_NUM_FORMS": "0", "p-MAX_NUM_FORMS": "1000",
        "p-0-id": str(principal.pk), "p-0-nombre": "Dra. Prueba", "p-0-activo": "on", "p-0-orden": "0",
        "p-1-nombre": "Dr. Nuevo", "p-1-activo": "on", "p-1-orden": "1", "p-1-servicios": [str(limpieza.pk)],
    }
    r = panel.post(f"/panel/n/{consultorio.pk}/?p=equipo", datos)
    assert r.status_code == 302, r.content
    nuevo = consultorio.profesionales.get(nombre="Dr. Nuevo")
    assert list(nuevo.servicios.all()) == [limpieza]
