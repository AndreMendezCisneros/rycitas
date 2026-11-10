"""Criterio de salida: dos reservas simultáneas por la misma hora nunca terminan en dos citas.

Hilos reales y transacciones reales contra PostgreSQL; aquí es donde un error de carrera aparecería.
"""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import pytest
from django.db import connection
from django.test import Client

from agenda.models import Tratamiento
from citas.models import Cita, Estado
from .conftest import AHORA, crear_consultorio, reservar

HILOS = 12


def _en_paralelo(funcion):
    barrera = Barrier(HILOS)

    def tarea(n):
        try:
            barrera.wait()
            return funcion(n)
        finally:
            connection.close()

    with ThreadPoolExecutor(max_workers=HILOS) as hilos:
        return list(hilos.map(tarea, range(HILOS)))


@pytest.mark.django_db(transaction=True)
@pytest.mark.parametrize("ronda", range(3))
def test_una_gana_y_las_demas_reciben_horario_tomado(ronda):
    consultorio = crear_consultorio()
    Tratamiento.objects.create(consultorio=consultorio, nombre="Limpieza", duracion_min=30, margen_min=10)

    def intento(n):
        cliente = Client(headers={"cf-connecting-ip": f"200.0.{ronda}.{n}"})
        return reservar(cliente, celular=f"9870000{n:02d}")

    respuestas = _en_paralelo(intento)
    codigos = sorted(r.status_code for r in respuestas)

    assert codigos == [201] + [409] * (HILOS - 1), [r.content for r in respuestas]
    perdedoras = [r.json() for r in respuestas if r.status_code == 409]
    assert all(p["codigo"] == "horario_tomado" for p in perdedoras)
    assert Cita.objects.filter(estado=Estado.POR_APROBAR).count() == 1


@pytest.mark.django_db(transaction=True)
def test_citas_que_se_cruzan_parcialmente_tampoco_entran_a_la_vez():
    consultorio = crear_consultorio()
    Tratamiento.objects.create(consultorio=consultorio, nombre="Limpieza", duracion_min=60)
    horas = [AHORA.replace(hour=10, minute=(n % 4) * 15) for n in range(HILOS)]

    def intento(n):
        cliente = Client(headers={"cf-connecting-ip": f"200.9.0.{n}"})
        return reservar(cliente, inicio=horas[n], celular=f"9870001{n:02d}")

    _en_paralelo(intento)
    activas = list(Cita.objects.filter(estado=Estado.POR_APROBAR).order_by("inicio"))
    assert activas
    for anterior, siguiente in zip(activas, activas[1:]):
        assert anterior.fin_ocupado <= siguiente.inicio


@pytest.mark.verificacion_whatsapp
@pytest.mark.django_db(transaction=True)
def test_el_mismo_mensaje_entregado_a_la_vez_se_procesa_una_vez():
    from mensajeria.models import MensajeEntrante
    from mensajeria.webhook import procesar_mensaje

    consultorio = crear_consultorio()
    Tratamiento.objects.create(consultorio=consultorio, nombre="Limpieza", duracion_min=30)
    cliente = Client(headers={"cf-connecting-ip": "200.9.1.1"})
    codigo = reservar(cliente).json()["codigo"]
    mensaje = {"id": "wamid.1", "from": "51987654321", "type": "text", "text": {"body": f"Código: {codigo}"}}

    def intento(_):
        try:
            procesar_mensaje(mensaje)
        except Exception as error:  # noqa: BLE001 - se devuelve para afirmar que no hubo ninguno
            return error
        return None

    errores = [e for e in _en_paralelo(intento) if e is not None]
    assert errores == []
    assert MensajeEntrante.objects.count() == 1
    cita = Cita.objects.get()
    assert cita.estado == Estado.PROGRAMADA
    assert cita.eventos.filter(valor_nuevo=Estado.PROGRAMADA).count() == 1
