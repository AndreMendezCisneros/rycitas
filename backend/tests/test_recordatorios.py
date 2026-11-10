"""Fase 2: aviso al profesional antes de cada cita y avisos que cada cuenta puede apagar."""
from datetime import timedelta

import pytest

from agenda.models import Tratamiento
from citas.models import Cita, Estado
from consultorios.models import Dispositivo, Profesional, Usuario
from mensajeria import push, tareas
from mensajeria.models import AvisoPendiente
from .conftest import AHORA, ApiDoctor, crear_consultorio

pytestmark = pytest.mark.django_db


@pytest.fixture
def barberia(db):
    c = crear_consultorio(slug="barba", nombre="Barbería Wari", rubro="barberia",
                          opciones={"modo_agenda": "por_profesional"})
    principal = c.profesional_principal()
    principal.nombre = "Juan"
    principal.save()
    Profesional.objects.create(consultorio=c, nombre="Pedro", orden=1)
    return c


@pytest.fixture
def corte(barberia):
    return Tratamiento.objects.create(consultorio=barberia, nombre="Corte clásico", duracion_min=30, precio_desde=20)


@pytest.fixture
def equipo(barberia):
    juan, pedro = barberia.profesionales.order_by("orden", "id")
    general = Usuario.objects.create_user("g@barba.test", "clave-segura-123", consultorio=barberia)
    de_juan = Usuario.objects.create_user("j@barba.test", "clave-segura-123", consultorio=barberia, profesional=juan)
    for usuario, token in ((general, "tok-general"), (de_juan, "tok-juan")):
        Dispositivo.objects.create(usuario=usuario, token_fcm=token)
    return {"juan": juan, "pedro": pedro, "general": general, "de_juan": de_juan}


def _cita(general, corte, profesional, hora=9, minuto=0, celular="987654321"):
    r = ApiDoctor(general).post("/citas", {
        "tratamiento_id": corte.pk, "inicio": AHORA.replace(hour=hora, minute=minuto).isoformat(),
        "nombre": "Rosa Paz", "celular": celular, "profesional_id": profesional.pk,
    })
    assert r.status_code == 201, r.content
    return Cita.objects.get(pk=r.json()["cita_id"])


def _tokens(aviso: AvisoPendiente) -> set[str]:
    destinos = push._dispositivos(
        aviso.consultorio_id, aviso.profesional_id, aviso.datos.get("tipo", ""), aviso.solo_profesional
    )
    return set(destinos.values_list("token_fcm", flat=True))


def test_avisa_al_profesional_antes_de_su_cita(reloj, corte, equipo):
    _cita(equipo["general"], corte, equipo["juan"])
    assert tareas.recordar_citas_proximas() == 0  # 8:00: la cita de las 9:00 aún está lejos
    reloj.avanzar(minutes=35)
    assert tareas.recordar_citas_proximas() == 1
    aviso = AvisoPendiente.objects.get(datos__tipo="cita_proxima")
    # Sin nombre ni servicio (DAT-05): se ve en la pantalla bloqueada y pasa por Google.
    assert aviso.titulo == "En 25 min: tu próxima cita"
    assert aviso.cuerpo == "A las 09:00 · con Juan"
    # Solo a Juan: la cuenta general no recibe un aviso por cada cita de cada profesional.
    assert _tokens(aviso) == {"tok-juan"}
    reloj.avanzar(minutes=5)
    assert tareas.recordar_citas_proximas() == 0  # no se repite


def test_si_el_profesional_no_tiene_cuenta_le_llega_a_la_general(reloj, corte, equipo):
    _cita(equipo["general"], corte, equipo["pedro"])
    reloj.avanzar(minutes=35)
    tareas.recordar_citas_proximas()
    assert _tokens(AvisoPendiente.objects.get(datos__tipo="cita_proxima")) == {"tok-general"}


def test_una_cita_movida_vuelve_a_avisar_y_una_por_confirmar_no(reloj, corte, equipo):
    cita = _cita(equipo["general"], corte, equipo["juan"])
    reloj.avanzar(minutes=35)
    tareas.recordar_citas_proximas()
    # Se adelanta a las 8:50: es otra hora, así que vuelve a salir su aviso.
    cita.inicio = AHORA.replace(hour=8, minute=50)
    cita.fin = cita.fin_ocupado = cita.inicio + timedelta(minutes=30)
    cita.save()
    assert tareas.recordar_citas_proximas() == 1
    assert AvisoPendiente.objects.filter(datos__tipo="cita_proxima").count() == 2
    Cita.objects.filter(pk=cita.pk).update(estado=Estado.POR_APROBAR)
    AvisoPendiente.objects.all().delete()
    assert tareas.recordar_citas_proximas() == 0


def test_el_negocio_puede_apagar_el_aviso_previo(reloj, barberia, corte, equipo):
    _cita(equipo["general"], corte, equipo["juan"])
    barberia.opciones = {**barberia.opciones, "recordar_cita_min": 0}
    barberia.save()
    reloj.avanzar(minutes=55)
    assert tareas.recordar_citas_proximas() == 0


def test_cada_cuenta_apaga_los_avisos_que_no_quiere(corte, equipo):
    de_juan = ApiDoctor(equipo["de_juan"])
    tipos = {t["tipo"]: t["activo"] for t in de_juan.get("/avisos").json()["tipos"]}
    assert tipos == {"por_aprobar": True, "nueva_cita": True, "cita_proxima": True, "recordatorios": True}
    r = de_juan.put("/avisos", {"apagados": ["por_aprobar", "inventado"]})
    assert r.status_code == 200
    equipo["de_juan"].refresh_from_db()
    assert equipo["de_juan"].avisos_apagados == ["por_aprobar"]
    destinos = push._dispositivos(equipo["juan"].consultorio_id, equipo["juan"].pk, "por_aprobar")
    assert set(destinos.values_list("token_fcm", flat=True)) == {"tok-general"}
    destinos = push._dispositivos(equipo["juan"].consultorio_id, equipo["juan"].pk, "nueva_cita")
    assert set(destinos.values_list("token_fcm", flat=True)) == {"tok-general", "tok-juan"}


def test_solo_la_cuenta_general_cambia_los_minutos(barberia, equipo):
    assert ApiDoctor(equipo["de_juan"]).put("/avisos", {"recordar_cita_min": 15}).status_code == 403
    general = ApiDoctor(equipo["general"])
    assert general.put("/avisos", {"recordar_cita_min": 7}).status_code == 422
    r = general.put("/avisos", {"recordar_cita_min": 15})
    assert r.status_code == 200 and r.json()["recordar_cita_min"] == 15
    barberia.refresh_from_db()
    assert barberia.opciones_efectivas["recordar_cita_min"] == 15
