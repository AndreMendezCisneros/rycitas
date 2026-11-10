"""Cuenta general frente a cuenta de profesional, turnos de la agenda, un número sin citas cruzadas y el panel."""
from datetime import time, timedelta

import pytest

from agenda.models import HorarioSemanal, Tratamiento
from citas.models import Cita, Estado
from consultorios.models import Profesional, Usuario, validar_turnos
from .conftest import AHORA, ApiDoctor, crear_consultorio, reservar

pytestmark = pytest.mark.django_db


@pytest.fixture
def barberia(db):
    c = crear_consultorio(slug="barba", nombre="Barbería Wari", rubro="barberia",
                          opciones={"modo_agenda": "por_profesional"})
    principal = c.profesional_principal()
    principal.nombre = "Juan"
    principal.save()
    Profesional.objects.create(consultorio=c, nombre="Pedro", orden=1)
    for dia in range(6):  # además del tramo de 9 a 13, uno de tarde: hay dos turnos que probar
        HorarioSemanal.objects.create(consultorio=c, dia_semana=dia, hora_inicio=time(14), hora_fin=time(19))
    return c


@pytest.fixture
def corte(barberia):
    return Tratamiento.objects.create(consultorio=barberia, nombre="Corte clásico", duracion_min=30, precio_desde=20)


@pytest.fixture
def juan_pedro(barberia):
    return list(barberia.profesionales.order_by("orden", "id"))


@pytest.fixture
def general(barberia):
    return ApiDoctor(Usuario.objects.create_user("g@barba.test", "clave-segura-123", consultorio=barberia))


@pytest.fixture
def de_pedro(barberia, juan_pedro):
    return ApiDoctor(Usuario.objects.create_user("p@barba.test", "clave-segura-123", consultorio=barberia,
                                                 profesional=juan_pedro[1]))


def _reservar(cliente, corte, profesional, **extra):
    r = reservar(cliente, slug="barba", motivo=corte.slug, profesional=profesional.pk, **extra)
    assert r.status_code == 201, r.content
    return r


def _cita_de_juan(cliente, corte, juan):
    _reservar(cliente, corte, juan)
    return Cita.objects.get(profesional=juan)


# --- Cuentas -------------------------------------------------------------------------------------------


@pytest.mark.parametrize("accion", ["aprobar", "rechazar", "iniciar", "llego", "cancelar", "recordado"])
def test_una_cuenta_de_profesional_no_toca_citas_ajenas(cliente, corte, juan_pedro, de_pedro, accion):
    cita = _cita_de_juan(cliente, corte, juan_pedro[0])
    r = de_pedro.post(f"/citas/{cita.pk}/{accion}", {})
    assert r.status_code == 404, r.content
    assert Cita.objects.get(pk=cita.pk).estado == cita.estado


def test_una_cuenta_de_profesional_no_mueve_citas_ajenas(cliente, corte, juan_pedro, de_pedro):
    cita = _cita_de_juan(cliente, corte, juan_pedro[0])
    r = de_pedro.post(f"/citas/{cita.pk}/reprogramar", {"inicio": AHORA.replace(hour=12).isoformat()})
    assert r.status_code == 404


def test_por_confirmar_se_filtra_por_la_cuenta(cliente, corte, juan_pedro, general, de_pedro):
    _cita_de_juan(cliente, corte, juan_pedro[0])
    assert de_pedro.get("/citas/por-aprobar").json()["citas"] == []
    assert de_pedro.get("/agenda", fecha=AHORA.date().isoformat()).json()["por_aprobar"] == 0
    assert len(general.get("/citas/por-aprobar").json()["citas"]) == 1


def test_la_cuenta_de_profesional_agenda_siempre_en_su_agenda(corte, juan_pedro, de_pedro):
    juan, pedro = juan_pedro
    r = de_pedro.post("/citas", {"tratamiento_id": corte.pk, "inicio": AHORA.replace(hour=12).isoformat(),
                                 "nombre": "Ana Paz", "celular": "987654321", "profesional_id": juan.pk})
    assert r.status_code == 201, r.content
    assert Cita.objects.get().profesional == pedro


def test_negocio_dice_si_la_cuenta_es_general(general, de_pedro):
    assert general.get("/negocio").json()["cuenta"]["es_general"] is True
    assert de_pedro.get("/negocio").json()["cuenta"]["es_general"] is False


# --- Turnos --------------------------------------------------------------------------------------------


def test_la_agenda_viene_dividida_en_turnos(cliente, corte, juan_pedro, general):
    juan = juan_pedro[0]
    _reservar(cliente, corte, juan, inicio=AHORA.replace(hour=10))
    _reservar(cliente, corte, juan, inicio=AHORA.replace(hour=15), celular="+51987000002")
    Cita.objects.filter(inicio=AHORA.replace(hour=15)).update(estado=Estado.PROGRAMADA)
    turnos = general.get("/agenda", fecha=AHORA.date().isoformat()).json()["turnos"]
    assert [(t["nombre"], t["citas"], t["por_confirmar"]) for t in turnos] == [("Mañana", 1, 1), ("Tarde", 1, 0)]
    assert turnos[0]["desde"] == 0 and turnos[0]["hasta"] == 13 * 60 and turnos[1]["hasta"] == 24 * 60
    semana = general.get("/agenda/semana", desde=AHORA.date().isoformat()).json()["dias"][0]["turnos"]
    assert [t["citas"] for t in semana] == [1, 1]


def test_la_cuenta_general_cambia_los_turnos(barberia, general, de_pedro):
    nuevos = [{"nombre": "Mañana", "hasta": "12:00"}, {"nombre": "Tarde", "hasta": "18:00"}, {"nombre": "Noche"}]
    r = general.put("/turnos", {"turnos": nuevos})
    assert r.status_code == 200, r.content
    barberia.refresh_from_db()
    assert [t["hasta"] for t in barberia.opciones_efectivas["turnos"]] == ["12:00", "18:00", "24:00"]
    assert de_pedro.put("/turnos", {"turnos": nuevos}).status_code == 403
    desordenados = [{"nombre": "A", "hasta": "14:00"}, {"nombre": "B", "hasta": "13:00"}, {"nombre": "C"}]
    assert general.put("/turnos", {"turnos": desordenados}).status_code == 422


def test_validar_turnos():
    assert validar_turnos([{"nombre": " Único ", "hasta": "08:00"}]) == [{"nombre": "Único", "hasta": "24:00"}]
    for malos in ([], [{"nombre": ""}], [{"nombre": "A", "hasta": "25:00"}, {"nombre": "B"}], [{"nombre": "x"}] * 4):
        with pytest.raises(ValueError):
            validar_turnos(malos)


# --- Un número, una cita a la vez ----------------------------------------------------------------------


def test_el_mismo_numero_no_reserva_a_la_misma_hora_con_otro_profesional(cliente, corte, juan_pedro):
    juan, pedro = juan_pedro
    _reservar(cliente, corte, juan)
    r = reservar(cliente, slug="barba", motivo=corte.slug, profesional=pedro.pk)
    assert r.status_code == 409 and r.json()["codigo"] == "paciente_ocupado", r.content
    assert "Juan" in r.json()["detail"]
    # Otro número a la misma hora con Pedro sí puede, y el mismo número a otra hora también.
    _reservar(cliente, corte, pedro, celular="+51987000009")
    _reservar(cliente, corte, pedro, inicio=AHORA.replace(hour=11, minute=30))


def test_por_telefono_tampoco_se_cruzan(cliente, corte, juan_pedro, general):
    juan, pedro = juan_pedro
    _reservar(cliente, corte, juan)
    r = general.post("/citas", {"tratamiento_id": corte.pk, "inicio": AHORA.replace(hour=11, minute=15).isoformat(),
                                "nombre": "Rosa Paz", "celular": "987654321", "profesional_id": pedro.pk})
    assert r.status_code == 409 and r.json()["codigo"] == "paciente_ocupado"


def test_mover_no_cruza_con_otra_cita_del_mismo_numero(cliente, corte, juan_pedro, general):
    juan, pedro = juan_pedro
    _reservar(cliente, corte, juan)
    _reservar(cliente, corte, pedro, inicio=AHORA.replace(hour=14))
    de_pedro = Cita.objects.get(profesional=pedro)
    r = general.post(f"/citas/{de_pedro.pk}/reprogramar", {"inicio": AHORA.replace(hour=11).isoformat()})
    assert r.status_code == 409 and r.json()["codigo"] == "paciente_ocupado"
    # A una hora libre para el número, sí.
    r = general.post(f"/citas/{de_pedro.pk}/reprogramar", {"inicio": AHORA.replace(hour=16).isoformat()})
    assert r.status_code == 200, r.content


def test_una_cita_rechazada_no_bloquea_al_numero(cliente, corte, juan_pedro, general):
    juan, pedro = juan_pedro
    cita = _cita_de_juan(cliente, corte, juan)
    assert general.post(f"/citas/{cita.pk}/rechazar", {}).status_code == 200
    _reservar(cliente, corte, pedro)


# --- Panel ---------------------------------------------------------------------------------------------


def test_el_panel_cuenta_las_citas_por_venir_del_mes(cliente, consultorio, limpieza):
    from django.test import Client

    assert reservar(cliente, inicio=AHORA.replace(hour=11) + timedelta(days=1)).status_code == 201
    admin = Usuario.objects.create_superuser("admin@x.test", "clave-segura-123")
    panel = Client()
    panel.force_login(admin)
    r = panel.get(f"/panel/n/{consultorio.pk}/")
    assert r.status_code == 200
    assert r.context["kpis"]["citas"] == 1
    assert r.context["proximas"] == 1


# --- SEG-03: la cuenta de un profesional no configura el negocio -----------------------------------------


def _rutas_de_configuracion(corte):
    tramos = {"tramos": [{"dia_semana": 0, "hora_inicio": "08:00", "hora_fin": "09:00"}]}
    servicio = {"nombre": "Afeitado", "duracion_min": 20}
    return [
        ("post", "/horario/impacto", tramos),
        ("put", "/horario", tramos),
        ("post", "/tratamientos", servicio),
        ("put", f"/tratamientos/{corte.pk}", servicio),
        ("delete", f"/tratamientos/{corte.pk}", None),
        ("put", "/turnos", {"turnos": []}),
        ("put", "/fidelidad", {"activa": True, "meta": 5, "premio": "Corte gratis"}),
        ("post", "/cupones", {"codigo": "X1", "titulo": "X", "descuento_pct": 10, "vence_el": "2026-12-31"}),
        ("post", "/campanas", {"titulo": "Hola", "mensaje": "Hola"}),
    ]


@pytest.mark.parametrize("indice", range(9))
def test_profesional_no_cambia_configuracion_del_negocio(barberia, corte, de_pedro, indice):
    metodo, ruta, datos = _rutas_de_configuracion(corte)[indice]
    antes = (
        list(HorarioSemanal.objects.filter(consultorio=barberia).values_list("dia_semana", "hora_inicio", "hora_fin")),
        list(Tratamiento.objects.filter(consultorio=barberia).values_list("nombre", "visible", "reservable")),
    )
    r = getattr(de_pedro, metodo)(ruta, datos) if datos is not None else getattr(de_pedro, metodo)(ruta)
    assert r.status_code == 403, (ruta, r.content)
    assert r.json()["codigo"] == "solo_general"
    despues = (
        list(HorarioSemanal.objects.filter(consultorio=barberia).values_list("dia_semana", "hora_inicio", "hora_fin")),
        list(Tratamiento.objects.filter(consultorio=barberia).values_list("nombre", "visible", "reservable")),
    )
    assert antes == despues


def test_el_bloqueo_de_un_profesional_solo_cierra_su_agenda(barberia, juan_pedro, de_pedro, general):
    from agenda.models import Bloqueo

    rango = {"inicio": AHORA.replace(hour=9).isoformat(), "fin": AHORA.replace(hour=12).isoformat()}
    r = de_pedro.post("/bloqueos", rango)
    assert r.status_code == 201
    assert Bloqueo.objects.get(pk=r.json()["id"]).profesional == juan_pedro[1]

    # El cierre del negocio entero lo pone la cuenta general, y el profesional no lo puede quitar.
    del_negocio = general.post("/bloqueos", rango).json()["id"]
    assert Bloqueo.objects.get(pk=del_negocio).profesional is None
    assert de_pedro.delete(f"/bloqueos/{del_negocio}").status_code == 404
    assert Bloqueo.objects.filter(pk=del_negocio).exists()
    assert de_pedro.delete(f"/bloqueos/{r.json()['id']}").status_code == 204


def test_el_impacto_de_un_bloqueo_de_profesional_solo_trae_sus_citas(cliente, corte, juan_pedro, de_pedro):
    _cita_de_juan(cliente, corte, juan_pedro[0])
    r = de_pedro.get("/bloqueos/impacto", inicio=AHORA.replace(hour=8).isoformat(),
                     fin=AHORA.replace(hour=19).isoformat())
    assert r.status_code == 200 and r.json()["citas"] == []


def test_un_bloqueo_no_dura_mas_de_un_anio(general):
    r = general.post("/bloqueos", {"inicio": AHORA.isoformat(), "fin": (AHORA + timedelta(days=400)).isoformat()})
    assert r.status_code == 422
