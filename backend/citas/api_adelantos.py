"""Endpoints de adelantos (Fase E). Con el interruptor apagado responden 404, como si no existieran."""
from decimal import Decimal

from django.shortcuts import get_object_or_404
from ninja import Router, Schema

from citas import adelantos
from citas.models import Cita
from denticita.idempotencia import idempotente

router = Router(tags=["adelantos"])


class AdelantoEntrada(Schema):
    monto: Decimal
    metodo: str
    operacion: str = ""
    nota: str = ""


class DevolverEntrada(Schema):
    nota: str = ""


@router.get("/citas/{cita_id}/adelantos")
def listar(request, cita_id: int):
    consultorio = request.auth.consultorio
    adelantos.exigir_habilitados(consultorio)
    filtro = {"profesional_id": request.auth.profesional_id} if request.auth.profesional_id else {}
    cita = get_object_or_404(Cita, consultorio=consultorio, pk=cita_id, **filtro)
    return {
        "adelantos": [adelantos.adelanto_publico(a) for a in cita.adelantos.all()],
        "recibido_centimos": adelantos.total_recibido(cita),
    }


@router.post("/citas/{cita_id}/adelantos", response={201: dict})
@idempotente
def registrar(request, cita_id: int, datos: AdelantoEntrada):
    a = adelantos.registrar(
        request.auth.consultorio, request.auth, cita_id, datos.monto, datos.metodo, datos.operacion, datos.nota
    )
    return 201, adelantos.adelanto_publico(a)


@router.post("/adelantos/{adelanto_id}/recibido")
@idempotente
def recibido(request, adelanto_id: int):
    return adelantos.adelanto_publico(adelantos.conciliar(request.auth.consultorio, request.auth, adelanto_id))


@router.post("/adelantos/{adelanto_id}/devuelto")
@idempotente
def devuelto(request, adelanto_id: int, datos: DevolverEntrada | None = None):
    nota = datos.nota if datos else ""
    return adelantos.adelanto_publico(adelantos.devolver(request.auth.consultorio, request.auth, adelanto_id, nota))
