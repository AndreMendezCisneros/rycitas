"""RNF-08: un consultorio nunca ve datos de otro. Estas pruebas intentan cruzarlos y deben fallar."""
from datetime import timedelta

import pytest

from agenda.models import Bloqueo, Tratamiento
from citas.models import Adelanto, Cita, Estado, EventoCita, Paciente
from clientes.models import Cupon
from consultorios.models import Usuario
from denticita.api import api_doctor
from .conftest import AHORA, ApiDoctor

# Con los adelantos encendidos: así sus rutas también se prueban de verdad y no solo por estar apagadas.
pytestmark = [pytest.mark.django_db, pytest.mark.pagos_adelantados]


@pytest.fixture
def ajeno(otro_consultorio, consultorio):
    """Datos del otro consultorio, con la misma forma que tendrían los propios."""
    for c in (consultorio, otro_consultorio):
        c.opciones = {**c.opciones, "adelantos": True}
        c.save()
    tratamiento = Tratamiento.objects.create(consultorio=otro_consultorio, nombre="Secreto", duracion_min=30)
    paciente = Paciente.objects.create(consultorio=otro_consultorio, nombre="Paciente Ajeno", celular="+51900000099")
    inicio = AHORA.replace(hour=10)
    fin = inicio + timedelta(minutes=30)
    cita = Cita.objects.create(
        consultorio=otro_consultorio,
        paciente=paciente,
        tratamiento=tratamiento,
        inicio=inicio,
        fin=fin,
        fin_ocupado=fin,
        estado=Estado.PROGRAMADA,
        token_gestion="token-ajeno",
    )
    bloqueo = Bloqueo.objects.create(consultorio=otro_consultorio, inicio=inicio, fin=fin, motivo="Bloqueo ajeno")
    adelanto = Adelanto.objects.create(cita=cita, monto=1000, metodo="yape")
    cupon = Cupon.objects.create(consultorio=otro_consultorio, codigo="AJENO", titulo="Ajeno", descuento_pct=10,
                                 vence_el=(AHORA + timedelta(days=9)).date())
    return {"cita": cita, "paciente": paciente, "tratamiento": tratamiento, "bloqueo": bloqueo, "adelanto": adelanto,
            "cupon": cupon}


def ruta_de(plantilla: str, ajeno: dict) -> str:
    return (
        plantilla.replace("{cita_id}", str(ajeno["cita"].pk))
        .replace("{paciente_id}", str(ajeno["paciente"].pk))
        .replace("{tratamiento_id}", str(ajeno["tratamiento"].pk))
        .replace("{bloqueo_id}", str(ajeno["bloqueo"].pk))
        .replace("{adelanto_id}", str(ajeno["adelanto"].pk))
        .replace("{cupon_id}", str(ajeno["cupon"].pk))
    )


def rutas_con_identificador():
    """Se toman de la API real: si alguien agrega una ruta nueva con id, entra sola a esta prueba."""
    rutas = []
    for prefijo, router in api_doctor._routers:
        for ruta, vista in router.path_operations.items():
            if "{" not in ruta:
                continue
            for operacion in vista.operations:
                for metodo in operacion.methods:
                    rutas.append((metodo, ruta))
    return sorted(set(rutas))


CUERPOS = {
    "POST /citas/{cita_id}/extender": {"minutos": 10},
    "POST /citas/{cita_id}/demora": {"minutos": 10},
    "POST /citas/{cita_id}/reprogramar": {"inicio": AHORA.replace(hour=11).isoformat()},
    "POST /citas/{cita_id}/asistencia": {"confirmada": True},
    "PUT /tratamientos/{tratamiento_id}": {"nombre": "Robado", "duracion_min": 30},
    "POST /citas/{cita_id}/adelantos": {"monto": "10", "metodo": "yape"},
}


@pytest.mark.parametrize("metodo,ruta", rutas_con_identificador())
def test_ninguna_ruta_con_id_alcanza_datos_ajenos(api, ajeno, metodo, ruta):
    url = ruta_de(ruta, ajeno)
    cuerpo = CUERPOS.get(f"{metodo} {ruta}", {})
    if metodo == "GET":
        respuesta = api.c.get(f"/api/v1{url}")
    else:
        respuesta = getattr(api.c, metodo.lower())(f"/api/v1{url}", cuerpo, content_type="application/json")
    assert respuesta.status_code == 404, f"{metodo} {ruta} respondió {respuesta.status_code}: {respuesta.content!r}"


def test_las_rutas_con_id_realmente_se_estan_probando():
    rutas = rutas_con_identificador()
    assert ("POST", "/citas/{cita_id}/iniciar") in rutas
    assert ("DELETE", "/bloqueos/{bloqueo_id}") in rutas
    assert ("PUT", "/tratamientos/{tratamiento_id}") in rutas
    assert ("GET", "/pacientes/{paciente_id}") in rutas
    assert len(rutas) >= 13


def test_los_intentos_no_cambiaron_nada(api, ajeno):
    for metodo, ruta in rutas_con_identificador():
        if metodo == "GET":
            continue
        url = ruta_de(ruta, ajeno)
        cuerpo = CUERPOS.get(f"{metodo} {ruta}", {})
        getattr(api.c, metodo.lower())(f"/api/v1{url}", cuerpo, content_type="application/json")
    cita = Cita.objects.get(pk=ajeno["cita"].pk)
    assert cita.estado == Estado.PROGRAMADA
    assert cita.inicio == AHORA.replace(hour=10)
    assert not EventoCita.objects.filter(cita=cita).exists()
    assert Paciente.objects.get(pk=ajeno["paciente"].pk).bloqueado is False
    assert Adelanto.objects.get(pk=ajeno["adelanto"].pk).estado == Adelanto.EstadoAdelanto.PENDIENTE
    assert Adelanto.objects.filter(cita=cita).count() == 1
    assert Tratamiento.objects.get(pk=ajeno["tratamiento"].pk).nombre == "Secreto"
    assert Bloqueo.objects.filter(pk=ajeno["bloqueo"].pk).exists()


@pytest.mark.parametrize(
    "ruta,clave",
    [
        ("/agenda", "citas"),
        ("/agenda/semana", "dias"),
        ("/pacientes", "pacientes"),
        ("/tratamientos", "tratamientos"),
        ("/bloqueos", "bloqueos"),
        ("/citas/por-aprobar", "citas"),
    ],
)
def test_ningun_listado_incluye_datos_ajenos(api, ajeno, ruta, clave):
    respuesta = api.get(ruta)
    assert respuesta.status_code == 200
    contenido = respuesta.content.decode()
    assert clave in respuesta.json()
    assert "Paciente Ajeno" not in contenido
    assert "Secreto" not in contenido
    assert "Bloqueo ajeno" not in contenido


def test_la_busqueda_de_pacientes_no_cruza_consultorios(api, ajeno):
    assert api.get("/pacientes", q="Ajeno").json()["pacientes"] == []
    assert api.get("/pacientes", q="900000099").json()["pacientes"] == []


def test_impacto_de_bloqueo_no_muestra_citas_ajenas(api, ajeno):
    r = api.get("/bloqueos/impacto", inicio=AHORA.isoformat(), fin=(AHORA + timedelta(hours=8)).isoformat())
    assert r.json()["citas"] == []


def test_la_cita_ajena_no_ocupa_mis_horas(api, limpieza, ajeno):
    dias = api.get("/citas/disponibilidad", tratamiento_id=limpieza.pk).json()["dias"]
    assert "2026-11-09T10:00:00-05:00" in dias[0]["horas"]


def test_no_se_puede_crear_cita_con_tratamiento_ajeno(api, ajeno):
    r = api.post(
        "/citas",
        {"tratamiento_id": ajeno["tratamiento"].pk, "inicio": AHORA.replace(hour=11).isoformat(), "nombre": "Ana", "celular": "987111444"},
    )
    assert r.status_code == 404


def test_no_se_consulta_disponibilidad_con_tratamiento_o_cita_ajenos(api, limpieza, ajeno):
    assert api.get("/citas/disponibilidad", tratamiento_id=ajeno["tratamiento"].pk).status_code == 404
    assert api.get("/citas/disponibilidad", tratamiento_id=limpieza.pk, excluir_cita=ajeno["cita"].pk).status_code == 404


def test_el_horario_se_guarda_solo_en_el_propio_consultorio(api, ajeno, otro_consultorio):
    antes = otro_consultorio.horarios.count()
    api.put("/horario", {"tramos": []})
    assert otro_consultorio.horarios.count() == antes


def test_el_motivo_publico_de_otro_consultorio_no_sirve(cliente, consultorio, ajeno):
    from .conftest import reservar

    assert reservar(cliente, motivo="secreto").json()["codigo"] == "motivo_invalido"
    assert cliente.get("/public/v1/sonrisa/disponibilidad", {"motivo": "secreto"}).status_code == 404


def test_el_doctor_ajeno_si_ve_lo_suyo(ajeno, otro_consultorio):
    """Comprueba que las pruebas de arriba fallan por aislamiento y no porque los datos estén mal armados."""
    usuario = Usuario.objects.create_user("ajeno@x.test", "clave-segura-123", consultorio=otro_consultorio)
    api = ApiDoctor(usuario)
    assert api.get(f"/pacientes/{ajeno['paciente'].pk}").status_code == 200
    assert api.post(f"/citas/{ajeno['cita'].pk}/iniciar").status_code == 200
