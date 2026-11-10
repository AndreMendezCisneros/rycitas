"""Varios tipos de negocio, varios profesionales, precio ofertable, datos completos de la cita y suspensión."""
from datetime import time, timedelta
from urllib.parse import parse_qs, urlparse

import pytest

from agenda.models import Bloqueo, HorarioSemanal, Tratamiento
from citas.models import Cita, Estado
from consultorios.models import Consultorio, Profesional, Usuario
from consultorios.rubros import RUBROS
from .conftest import AHORA, ApiDoctor, crear_consultorio, reservar

pytestmark = pytest.mark.django_db


def texto_de(url: str) -> str:
    return parse_qs(urlparse(url).query)["text"][0]


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


def _juan_pedro(barberia):
    return list(barberia.profesionales.order_by("orden", "id"))


# --- Tipos de negocio -----------------------------------------------------------------------------


def test_todo_negocio_nace_con_su_profesional_principal(consultorio):
    assert consultorio.profesionales.count() == 1
    assert consultorio.profesional_principal().nombre == "Dra. Prueba"


def test_cada_tipo_de_negocio_tiene_vocabulario_servicios_y_horario():
    for clave, tipo in RUBROS.items():
        assert {"cliente", "servicio", "profesional", "local"} <= set(tipo["vocabulario"]), clave
        assert tipo["servicios"] and tipo["horario"], clave


def test_la_app_recibe_el_vocabulario_de_su_negocio(barberia):
    juan, _ = _juan_pedro(barberia)
    usuario = Usuario.objects.create_user("juan@barba.test", "clave-segura-123", consultorio=barberia, profesional=juan)
    datos = ApiDoctor(usuario).get("/negocio").json()
    assert datos["vocabulario"]["profesional"] == "barbero"
    assert datos["vocabulario"]["cliente"] == "cliente"
    assert datos["opciones"]["modo_agenda"] == "por_profesional"
    assert [p["nombre"] for p in datos["profesionales"]] == ["Juan", "Pedro"]
    assert datos["cuenta"]["profesional_id"] == juan.pk


def test_el_dental_sigue_hablando_de_pacientes(api):
    assert api.get("/negocio").json()["vocabulario"]["cliente"] == "paciente"


# --- Varios profesionales -------------------------------------------------------------------------


def test_dos_barberos_atienden_a_la_misma_hora(cliente, barberia, corte):
    assert reservar(cliente, slug="barba", motivo=corte.slug).status_code == 201
    assert reservar(cliente, slug="barba", motivo=corte.slug, celular="+51987000001").status_code == 201
    assert reservar(cliente, slug="barba", motivo=corte.slug, celular="+51987000002").status_code == 409
    assert {c.profesional.nombre for c in Cita.objects.all()} == {"Juan", "Pedro"}


def test_la_base_impide_dos_citas_del_mismo_profesional_a_la_vez(barberia, corte):
    from django.db import IntegrityError, transaction

    from citas.models import Paciente

    juan, pedro = _juan_pedro(barberia)
    paciente = Paciente.objects.create(consultorio=barberia, nombre="A", celular="+51987000009")
    inicio = AHORA.replace(hour=11)
    base = dict(consultorio=barberia, paciente=paciente, tratamiento=corte, inicio=inicio,
                fin=inicio + timedelta(minutes=30), fin_ocupado=inicio + timedelta(minutes=30), estado=Estado.PROGRAMADA)
    Cita.objects.create(**base, profesional=juan, token_gestion="1")
    Cita.objects.create(**base, profesional=pedro, token_gestion="2")
    with pytest.raises(IntegrityError), transaction.atomic():
        Cita.objects.create(**base, profesional=juan, token_gestion="3")


def test_cualquiera_reparte_al_que_tiene_menos_citas(cliente, barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    reservar(cliente, slug="barba", motivo=corte.slug, inicio=AHORA.replace(hour=10), profesional=juan.pk)
    reservar(cliente, slug="barba", motivo=corte.slug, celular="+51987000001")
    assert Cita.objects.get(inicio=AHORA.replace(hour=11)).profesional == pedro


def test_el_cliente_elige_con_quien(cliente, barberia, corte):
    _, pedro = _juan_pedro(barberia)
    r = reservar(cliente, slug="barba", motivo=corte.slug, profesional=pedro.pk)
    assert r.status_code == 201
    assert r.json()["profesional"] == "Pedro"


def test_con_agenda_compartida_no_se_elige_profesional(cliente, consultorio, limpieza):
    otro = Profesional.objects.create(consultorio=consultorio, nombre="Asistente")
    r = reservar(cliente, profesional=otro.pk)
    assert r.status_code == 201
    assert Cita.objects.get().profesional == consultorio.profesional_principal()


def test_la_disponibilidad_de_cualquiera_une_las_horas(cliente, barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    Bloqueo.objects.create(consultorio=barberia, profesional=juan, inicio=AHORA.replace(hour=9),
                           fin=AHORA.replace(hour=13))
    horas = lambda **p: cliente.get("/public/v1/barba/disponibilidad", {"motivo": corte.slug, **p}).json()["dias"]  # noqa: E731
    lunes = AHORA.date().isoformat()
    de_juan = next((d["horas"] for d in horas(profesional=juan.pk) if d["fecha"] == lunes), [])
    de_todos = next(d["horas"] for d in horas() if d["fecha"] == lunes)
    assert de_juan == []
    assert len(de_todos) > 0


def test_un_servicio_puede_ser_solo_de_un_profesional(cliente, barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    tinte = Tratamiento.objects.create(consultorio=barberia, nombre="Tinte", duracion_min=60)
    pedro.servicios.add(tinte)
    juan.servicios.add(corte)
    r = reservar(cliente, slug="barba", motivo=tinte.slug)
    assert r.status_code == 201
    assert Cita.objects.get().profesional == pedro
    assert reservar(cliente, slug="barba", motivo=tinte.slug, profesional=juan.pk,
                    celular="+51987000001").status_code == 422


def test_horario_propio_de_un_profesional(cliente, barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    HorarioSemanal.objects.create(consultorio=barberia, profesional=pedro, dia_semana=0, hora_inicio=time(15),
                                  hora_fin=time(18))
    assert reservar(cliente, slug="barba", motivo=corte.slug, profesional=pedro.pk).status_code == 409
    r = reservar(cliente, slug="barba", motivo=corte.slug, profesional=pedro.pk, inicio=AHORA.replace(hour=15))
    assert r.status_code == 201


def test_la_cuenta_de_profesional_solo_ve_su_agenda_y_la_general_ve_todas(cliente, barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    reservar(cliente, slug="barba", motivo=corte.slug, profesional=juan.pk)
    reservar(cliente, slug="barba", motivo=corte.slug, profesional=pedro.pk, celular="+51987000001")
    cuenta = ApiDoctor(Usuario.objects.create_user("p@barba.test", "clave-segura-123", consultorio=barberia,
                                                   profesional=pedro))
    propias = cuenta.get("/agenda").json()["citas"]
    assert [c["profesional"]["nombre"] for c in propias] == ["Pedro"]
    # Pida «Todos» (0) o la agenda de otro, una cuenta de profesional solo recibe la suya.
    assert [c["profesional"]["nombre"] for c in cuenta.get("/agenda", profesional=0).json()["citas"]] == ["Pedro"]
    semana = cuenta.get("/agenda/semana", profesional=juan.pk).json()["dias"][0]["citas"]
    assert [c["profesional"]["nombre"] for c in semana] == ["Pedro"]
    general = ApiDoctor(Usuario.objects.create_user("g@barba.test", "clave-segura-123", consultorio=barberia))
    assert len(general.get("/agenda", profesional=0).json()["citas"]) == 2
    assert len(general.get("/agenda/semana", profesional=juan.pk).json()["dias"][0]["citas"]) == 1


def test_varias_cuentas_comparten_una_agenda(cliente, consultorio, limpieza, doctor):
    asistente = Usuario.objects.create_user("asis@sonrisa.test", "clave-segura-123", consultorio=consultorio)
    reservar(cliente)
    assert len(ApiDoctor(asistente).get("/agenda").json()["citas"]) == 1
    assert len(ApiDoctor(doctor).get("/agenda").json()["citas"]) == 1


def test_el_doctor_crea_una_cita_para_un_profesional(barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    api = ApiDoctor(Usuario.objects.create_user("r@barba.test", "clave-segura-123", consultorio=barberia))
    inicio = AHORA.replace(hour=12).isoformat()
    r = api.post("/citas", {"tratamiento_id": corte.pk, "inicio": inicio, "nombre": "Ana Paz", "celular": "987654321",
                            "profesional_id": pedro.pk})
    assert r.status_code == 201, r.content
    assert Cita.objects.get().profesional == pedro


def test_mover_queda_en_la_agenda_del_mismo_profesional(cliente, barberia, corte):
    juan, pedro = _juan_pedro(barberia)
    reservar(cliente, slug="barba", motivo=corte.slug, profesional=pedro.pk)
    cita = Cita.objects.get()
    api = ApiDoctor(Usuario.objects.create_user("r@barba.test", "clave-segura-123", consultorio=barberia))
    r = api.post(f"/citas/{cita.pk}/reprogramar", {"inicio": AHORA.replace(hour=12).isoformat()})
    assert r.status_code == 200, r.content
    cita.refresh_from_db()
    assert cita.profesional == pedro and cita.inicio == AHORA.replace(hour=12)


# --- Precio ofertable y datos fijados --------------------------------------------------------------


def test_sin_la_opcion_no_se_puede_ofrecer_precio(cliente, barberia, corte):
    r = reservar(cliente, slug="barba", motivo=corte.slug, precio_ofrecido=18)
    assert r.status_code == 422
    assert r.json()["codigo"] == "precio_no_ofertable"


@pytest.fixture
def ofertable(barberia):
    barberia.opciones = {**barberia.opciones, "precio_ofertable": True}
    barberia.save()
    return barberia


def test_el_cliente_ofrece_y_el_negocio_acepta(cliente, ofertable, corte):
    r = reservar(cliente, slug="barba", motivo=corte.slug, precio_ofrecido=18)
    assert r.status_code == 201, r.content
    assert r.json()["precio_texto"] == "Tu oferta: S/ 18 (por confirmar)"
    cita = Cita.objects.get()
    assert (cita.precio_referencia, cita.precio_ofrecido) == (2000, 1800)
    api = ApiDoctor(Usuario.objects.create_user("r@barba.test", "clave-segura-123", consultorio=ofertable))
    datos = api.post(f"/citas/{cita.pk}/aprobar").json()
    cita.refresh_from_db()
    assert cita.precio_acordado == 1800
    assert "Precio acordado: S/ 18" in texto_de(datos["whatsapp_url"])


def test_el_negocio_pone_otro_precio_al_confirmar(cliente, ofertable, corte):
    reservar(cliente, slug="barba", motivo=corte.slug, precio_ofrecido=15)
    cita = Cita.objects.get()
    api = ApiDoctor(Usuario.objects.create_user("r@barba.test", "clave-segura-123", consultorio=ofertable))
    datos = api.post(f"/citas/{cita.pk}/aprobar", {"precio_acordado": 17.5}).json()
    cita.refresh_from_db()
    assert cita.precio_acordado == 1750
    assert "Precio acordado: S/ 17.50" in texto_de(datos["whatsapp_url"])
    assert cita.eventos.filter(tipo="precio", valor_nuevo="S/ 17.50").exists()


@pytest.mark.parametrize("monto", [0, -5, 41])
def test_la_oferta_tiene_limites(cliente, ofertable, corte, monto):
    r = reservar(cliente, slug="barba", motivo=corte.slug, precio_ofrecido=monto)
    assert r.status_code == 422


def test_la_cita_guarda_lo_acordado_aunque_cambie_el_servicio(cliente, limpieza):
    reservar(cliente)
    limpieza.nombre, limpieza.precio_desde, limpieza.duracion_min = "Profilaxis", 120, 60
    limpieza.save()
    cita = Cita.objects.get()
    assert (cita.servicio_nombre, cita.precio_referencia, cita.duracion_acordada_min) == ("Limpieza", 8000, 30)
    token = cita.token_gestion
    assert cliente.get(f"/public/v1/citas/{token}").json()["tratamiento"] == "Limpieza"


# --- Mensajes con todos los datos ----------------------------------------------------------------


def test_la_reserva_recibida_trae_todos_los_datos(cliente, consultorio, limpieza):
    datos = reservar(cliente).json()
    assert datos["tratamiento"] == "Limpieza" and datos["duracion_min"] == 30
    assert datos["profesional"] == "Dra. Prueba"
    assert datos["direccion"] == "Jr. Prueba 1"
    assert datos["precio_texto"] == "Precio de referencia: S/ 80"
    assert (datos["llegar_antes_min"], datos["hora_llegada"]) == (15, "10:45 a. m.")


def test_la_confirmacion_lleva_todos_los_datos_y_la_hora_de_llegada(cliente, limpieza, api):
    reservar(cliente)
    texto = texto_de(api.post(f"/citas/{Cita.objects.get().pk}/aprobar").json()["whatsapp_url"])
    for parte in ("Tratamiento: Limpieza (30 min)", "Con: Dra. Prueba", "Precio de referencia: S/ 80",
                  "Dirección: Jr. Prueba 1", "Te pedimos llegar 15 min antes, a las 10:45 a. m."):
        assert parte in texto, texto


def test_la_barberia_usa_su_propio_tiempo_de_llegada(cliente, barberia, corte):
    datos = reservar(cliente, slug="barba", motivo=corte.slug).json()
    assert datos["llegar_antes_min"] == 5
    barberia.opciones = {**barberia.opciones, "llegar_antes_min": 0}
    barberia.save()
    assert reservar(cliente, slug="barba", motivo=corte.slug, celular="+51987000001").json()["hora_llegada"] is None


def test_con_varios_profesionales_escribe_el_negocio(cliente, barberia, corte):
    reservar(cliente, slug="barba", motivo=corte.slug)
    api = ApiDoctor(Usuario.objects.create_user("r@barba.test", "clave-segura-123", consultorio=barberia))
    texto = texto_de(api.post(f"/citas/{Cita.objects.get().pk}/aprobar").json()["whatsapp_url"])
    assert texto.startswith("Hola Rosa, te escribimos de Barbería Wari.")
    assert "Servicio: Corte clásico" in texto


# --- Llegada e inasistencia ----------------------------------------------------------------------


def _programada(api, limpieza, hora=9):
    inicio = AHORA.replace(hour=hora).isoformat()
    r = api.post("/citas", {"tratamiento_id": limpieza.pk, "inicio": inicio, "nombre": "Ana Paz", "celular": "987654321"})
    return r.json()["cita_id"]


def test_marcar_llegada(api, limpieza, reloj):
    cita = _programada(api, limpieza)
    reloj.avanzar(minutes=55)
    assert api.post(f"/citas/{cita}/llego").status_code == 200
    assert Cita.objects.get().llegada_en == AHORA + timedelta(minutes=55)
    reloj.avanzar(minutes=30)
    assert api.post(f"/citas/{cita}/no-asistio").json()["codigo"] == "ya_llego"


def test_no_vino_solo_pasada_la_tolerancia(api, limpieza, reloj):
    cita = _programada(api, limpieza)
    reloj.avanzar(hours=1, minutes=10)  # 9:10
    r = api.post(f"/citas/{cita}/no-asistio")
    assert r.status_code == 409 and r.json()["codigo"] == "antes_de_tolerancia"
    reloj.avanzar(minutes=5)  # 9:15
    assert api.post(f"/citas/{cita}/no-asistio").status_code == 200


# --- Suspensión -----------------------------------------------------------------------------------


def test_suspendido_no_reserva_pero_las_citas_siguen(cliente, consultorio, limpieza, api):
    reservar(cliente)
    consultorio.suspendido = True
    consultorio.save()
    assert reservar(cliente, celular="+51987000001").status_code == 403
    assert cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"}).json()["dias"] == []
    assert cliente.get("/public/v1/sonrisa/perfil").json()["acepta_reservas"] is False
    cita = Cita.objects.get()
    assert cita.estado == Estado.POR_APROBAR
    assert api.post(f"/citas/{cita.pk}/aprobar").status_code == 200


def test_el_perfil_publico_trae_profesionales_y_opciones(cliente, barberia, corte):
    barberia.publicado = True
    barberia.save()
    datos = cliente.get("/public/v1/barba/perfil").json()
    assert datos["rubro"] == "barberia"
    assert datos["vocabulario"]["profesional"] == "barbero"
    assert [p["nombre"] for p in datos["profesionales"]] == ["Juan", "Pedro"]
    assert datos["opciones"]["elegir_profesional"] is True


def test_consultorios_existentes_quedan_como_odontologia(consultorio):
    assert Consultorio.objects.get().rubro == "odontologia"


def test_el_perfil_publico_trae_el_contenido_del_sitio(cliente, consultorio):
    consultorio.contenido_sitio = {"formas_de_pago": ["Yape"], "anos_practica": 12, "referencias": "Frente al parque"}
    consultorio.save()
    contenido = cliente.get("/public/v1/sonrisa/perfil").json()["contenido"]
    assert contenido["formas_de_pago"] == ["Yape"]
    assert contenido["anos_practica"] == 12
    assert contenido["referencias"] == "Frente al parque"
    assert contenido["bloques_confianza"]
