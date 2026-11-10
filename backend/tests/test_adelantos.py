"""Adelantos (Fase E): desarrollados y apagados. Sin el interruptor de la plataforma, no existen."""
import pytest

from citas.models import Adelanto, Cita
from .conftest import reservar

pytestmark = pytest.mark.django_db


@pytest.fixture
def cita(cliente, limpieza):
    reservar(cliente)
    return Cita.objects.get()


def _activar(consultorio):
    consultorio.opciones = {**consultorio.opciones, "adelantos": True}
    consultorio.save()


def test_apagados_en_la_plataforma_responden_404(api, consultorio, cita):
    _activar(consultorio)  # aunque el negocio lo pida, la plataforma manda
    assert consultorio.opciones_efectivas["adelantos"] is False
    assert api.get(f"/citas/{cita.pk}/adelantos").status_code == 404
    assert api.post(f"/citas/{cita.pk}/adelantos", {"monto": "20", "metodo": "yape"}).status_code == 404
    assert not Adelanto.objects.exists()


def test_el_panel_muestra_la_casilla_deshabilitada(consultorio):
    from panel.formularios import OpcionesForm

    assert OpcionesForm.para(consultorio).fields["adelantos"].disabled


@pytest.mark.pagos_adelantados
def test_con_la_plataforma_encendida_el_negocio_aun_decide(api, consultorio, cita):
    assert api.get(f"/citas/{cita.pk}/adelantos").status_code == 404
    _activar(consultorio)
    assert api.get(f"/citas/{cita.pk}/adelantos").status_code == 200


@pytest.mark.pagos_adelantados
def test_registrar_conciliar_y_devolver(api, consultorio, cita):
    _activar(consultorio)
    r = api.post(f"/citas/{cita.pk}/adelantos", {"monto": "20", "metodo": "yape", "operacion": "123456"})
    assert r.status_code == 201 and r.json()["estado"] == "pendiente" and r.json()["monto_centimos"] == 2000
    adelanto_id = r.json()["id"]
    assert api.get(f"/citas/{cita.pk}/adelantos").json()["recibido_centimos"] == 0

    assert api.post(f"/adelantos/{adelanto_id}/recibido").json()["estado"] == "recibido"
    assert api.get(f"/citas/{cita.pk}/adelantos").json()["recibido_centimos"] == 2000
    assert api.post(f"/adelantos/{adelanto_id}/recibido").status_code == 409

    devuelto = api.post(f"/adelantos/{adelanto_id}/devuelto", {"nota": "Canceló con tiempo"}).json()
    assert devuelto["estado"] == "devuelto" and devuelto["nota"] == "Canceló con tiempo"
    assert cita.eventos.filter(tipo="adelanto").count() == 3


@pytest.mark.pagos_adelantados
def test_no_supera_el_precio_ni_acepta_metodos_raros(api, consultorio, cita):
    _activar(consultorio)
    assert api.post(f"/citas/{cita.pk}/adelantos", {"monto": "81", "metodo": "yape"}).json()["codigo"] == "monto_excede"
    assert api.post(f"/citas/{cita.pk}/adelantos", {"monto": "10", "metodo": "bitcoin"}).status_code == 422
    assert api.post(f"/citas/{cita.pk}/adelantos", {"monto": "0", "metodo": "plin"}).status_code == 422


@pytest.mark.pagos_adelantados
def test_otro_negocio_no_ve_los_adelantos(api, otro_consultorio, cliente):
    from agenda.models import Tratamiento

    _activar(otro_consultorio)
    Tratamiento.objects.create(consultorio=otro_consultorio, nombre="Limpieza", duracion_min=30)
    reservar(cliente, slug="ajeno")
    ajena = Cita.objects.get()
    assert api.post(f"/citas/{ajena.pk}/adelantos", {"monto": "10", "metodo": "yape"}).status_code == 404


@pytest.mark.pagos_adelantados
def test_el_panel_habilita_la_casilla(consultorio):
    from panel.formularios import OpcionesForm

    assert not OpcionesForm.para(consultorio).fields["adelantos"].disabled
