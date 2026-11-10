"""Fidelización, cupones y campañas desde la app del negocio (/api/v1). Configurar y enviar: solo la cuenta general."""

import re
from datetime import date, timedelta
from urllib.parse import quote

from django.db import IntegrityError
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema

from agenda.models import Tratamiento
from citas.models import Paciente
from citas.servicios import a_centimos
from clientes import fidelidad
from clientes.models import Campana, Canje, Cliente, Cupon, CuponUsado, Sello, Segmento
from consultorios.permisos import solo_general
from denticita.errores import ErrorNegocio

router = Router(tags=["fidelización"])

MAX_CAMPANAS_SEMANA = 2


_solo_general = solo_general


class FidelidadEntrada(Schema):
    activa: bool
    meta: int
    premio: str
    puntualidad: bool = True


class CuponEntrada(Schema):
    titulo: str
    codigo: str = ""
    descuento_pct: int | None = None
    descuento_soles: float | None = None
    tratamiento_id: int | None = None
    segmento: str = Segmento.TODOS
    vence_el: date
    usos_max: int | None = None


class CampanaEntrada(Schema):
    titulo: str
    mensaje: str
    segmento: str = Segmento.TODOS
    cupon_id: int | None = None


# --- Tarjeta de sellos ---------------------------------------------------------------------------------


def _config(consultorio) -> dict:
    o = consultorio.opciones_efectivas
    inicio_mes = timezone.localdate().replace(day=1)
    clientes = fidelidad.clientes_del_negocio(consultorio)
    celulares = list(clientes.values_list("celular", flat=True))
    return {
        "activa": bool(o["fidelidad_activa"]),
        "meta": int(o["fidelidad_meta"]),
        "premio": o["fidelidad_premio"],
        "puntualidad": bool(o["sello_puntualidad"]),
        "resumen": {
            "clientes": len(celulares),
            "con_app": Cliente.objects.filter(celular__in=celulares, activo=True).count(),
            "sellos_mes": Sello.objects.filter(consultorio=consultorio, creado_en__date__gte=inicio_mes).count(),
            "premios_mes": Canje.objects.filter(consultorio=consultorio, creado_en__date__gte=inicio_mes).count(),
            "cupones_mes": CuponUsado.objects.filter(
                cupon__consultorio=consultorio, creado_en__date__gte=inicio_mes
            ).exclude(cita__estado__in=fidelidad.CAIDAS).count(),
        },
    }


@router.get("/fidelidad")
def ver_fidelidad(request):
    return _config(request.auth.consultorio)


@router.put("/fidelidad")
def guardar_fidelidad(request, datos: FidelidadEntrada):
    _solo_general(request)
    if not 3 <= datos.meta <= 20:
        raise ErrorNegocio("meta_invalida", "La tarjeta debe tener entre 3 y 20 sellos.", 422)
    premio = " ".join(datos.premio.split())
    if datos.activa and len(premio) < 3:
        raise ErrorNegocio("premio_invalido", "Escribe el premio, por ejemplo «Un corte gratis».", 422)
    consultorio = request.auth.consultorio
    consultorio.opciones = {
        **(consultorio.opciones or {}),
        "fidelidad_activa": datos.activa,
        "fidelidad_meta": datos.meta,
        "fidelidad_premio": premio[:120] or consultorio.opciones_efectivas["fidelidad_premio"],
        "sello_puntualidad": datos.puntualidad,
    }
    consultorio.save(update_fields=["opciones"])
    return _config(consultorio)


def _paciente(request, paciente_id: int) -> Paciente:
    return get_object_or_404(Paciente, consultorio=request.auth.consultorio, pk=paciente_id)


@router.get("/pacientes/{paciente_id}/tarjeta")
def ver_tarjeta(request, paciente_id: int):
    p = _paciente(request, paciente_id)
    return {
        **fidelidad.tarjeta(request.auth.consultorio, p.celular),
        "tiene_app": Cliente.objects.filter(celular=p.celular, activo=True).exists(),
    }


@router.post("/pacientes/{paciente_id}/canjear")
def canjear(request, paciente_id: int):
    """El cliente recibió su premio: la tarjeta vuelve a empezar."""
    p = _paciente(request, paciente_id)
    canje = fidelidad.canjear(request.auth.consultorio, p.celular)
    return {"premio": canje.premio, **fidelidad.tarjeta(request.auth.consultorio, p.celular)}


@router.post("/pacientes/{paciente_id}/regalar-sello")
def regalar_sello(request, paciente_id: int):
    _solo_general(request)
    p = _paciente(request, paciente_id)
    Sello.objects.create(consultorio=request.auth.consultorio, celular=p.celular, motivo=Sello.Motivo.AJUSTE)
    return fidelidad.tarjeta(request.auth.consultorio, p.celular)


# --- Cupones ---------------------------------------------------------------------------------------------


def _cupon(c: Cupon) -> dict:
    return {
        **fidelidad.cupon_publico(c),
        "segmento": c.segmento,
        "segmento_nombre": c.get_segmento_display(),
        "usos": fidelidad.usos(c),
        "usos_max": c.usos_max,
        "activo": c.activo,
        "vigente": fidelidad.cupon_vigente(c),
    }


@router.get("/cupones")
def cupones(request):
    lista = Cupon.objects.filter(consultorio=request.auth.consultorio).select_related("tratamiento")[:50]
    return {
        "cupones": [_cupon(c) for c in lista],
        "segmentos": [
            {"clave": k, "nombre": v, "clientes": fidelidad.del_segmento(request.auth.consultorio, k).count()}
            for k, v in Segmento.choices
        ],
    }


@router.post("/cupones", response={201: dict})
def crear_cupon(request, datos: CuponEntrada):
    _solo_general(request)
    consultorio = request.auth.consultorio
    titulo = " ".join(datos.titulo.split())
    if len(titulo) < 3:
        raise ErrorNegocio("titulo_invalido", "Escribe de qué es el cupón.", 422)
    if datos.segmento not in Segmento.values:
        raise ErrorNegocio("segmento_invalido", "Elige a quién va dirigido.", 422)
    pct = datos.descuento_pct
    monto = a_centimos(datos.descuento_soles) if datos.descuento_soles else None
    if (pct is None) == (monto is None):
        raise ErrorNegocio("descuento_invalido", "Indica un porcentaje o un monto en soles (uno de los dos).", 422)
    if pct is not None and not 5 <= pct <= 100:
        raise ErrorNegocio("descuento_invalido", "El porcentaje va de 5 a 100.", 422)
    if datos.vence_el < timezone.localdate():
        raise ErrorNegocio("vencimiento_invalido", "La fecha de vencimiento ya pasó.", 422)
    tratamiento = None
    if datos.tratamiento_id:
        tratamiento = get_object_or_404(Tratamiento, consultorio=consultorio, pk=datos.tratamiento_id)
    codigo = re.sub(r"[^A-Z0-9]", "", (datos.codigo or titulo).upper())[:12] or "CUPON"
    base = codigo
    for intento in range(1, 50):
        try:
            cupon = Cupon.objects.create(
                consultorio=consultorio,
                codigo=codigo,
                titulo=titulo[:80],
                descuento_pct=pct,
                descuento_monto=monto,
                tratamiento=tratamiento,
                segmento=datos.segmento,
                vence_el=datos.vence_el,
                usos_max=datos.usos_max if datos.usos_max and datos.usos_max > 0 else None,
            )
            break
        except IntegrityError:
            codigo = f"{base[:10]}{intento + 1}"
    else:
        raise ErrorNegocio("codigo_repetido", "Ya existe un cupón con ese código.", 409)
    return 201, _cupon(cupon)


@router.post("/cupones/{cupon_id}/desactivar")
def desactivar_cupon(request, cupon_id: int):
    _solo_general(request)
    cupon = get_object_or_404(Cupon, consultorio=request.auth.consultorio, pk=cupon_id)
    cupon.activo = False
    cupon.save(update_fields=["activo"])
    return _cupon(cupon)


# --- Campañas ------------------------------------------------------------------------------------------


def _destinatarios(consultorio, segmento: str):
    pacientes = list(fidelidad.del_segmento(consultorio, segmento).only("nombre", "celular"))
    silenciados = set(consultorio.clientes_silenciados.values_list("celular", flat=True))
    pacientes = [p for p in pacientes if p.celular not in silenciados]
    con_app = set(
        Cliente.objects.filter(celular__in=[p.celular for p in pacientes], activo=True, dispositivos__isnull=False)
        .values_list("celular", flat=True)
    )
    return pacientes, con_app


@router.get("/campanas")
def campanas(request):
    consultorio = request.auth.consultorio
    hace_semana = timezone.now() - timedelta(days=7)
    usadas = Campana.objects.filter(consultorio=consultorio, creado_en__gte=hace_semana).count()
    return {
        "campanas": [
            {
                "id": c.pk,
                "titulo": c.titulo,
                "mensaje": c.mensaje,
                "segmento_nombre": c.get_segmento_display(),
                "destinatarios": c.destinatarios,
                "con_app": c.con_app,
                "fecha": c.creado_en.isoformat(),
            }
            for c in Campana.objects.filter(consultorio=consultorio)[:20]
        ],
        "quedan_semana": max(0, MAX_CAMPANAS_SEMANA - usadas),
    }


@router.get("/campanas/previa")
def previa(request, segmento: str = Segmento.TODOS):
    pacientes, con_app = _destinatarios(request.auth.consultorio, segmento)
    return {"destinatarios": len(pacientes), "con_app": len(con_app)}


@router.post("/campanas", response={201: dict})
def enviar_campana(request, datos: CampanaEntrada):
    """Push gratis a quien tiene la app; para el resto, enlaces de WhatsApp listos para enviar a mano."""
    _solo_general(request)
    consultorio = request.auth.consultorio
    titulo, mensaje = " ".join(datos.titulo.split()), " ".join(datos.mensaje.split())
    if len(titulo) < 3 or len(mensaje) < 5:
        raise ErrorNegocio("campana_invalida", "Escribe un título y un mensaje.", 422)
    if datos.segmento not in Segmento.values:
        raise ErrorNegocio("segmento_invalido", "Elige a quién va dirigido.", 422)
    if Campana.objects.filter(consultorio=consultorio, creado_en__gte=timezone.now() - timedelta(days=7)).count() >= (
        MAX_CAMPANAS_SEMANA
    ):
        raise ErrorNegocio(
            "limite_campanas", f"Puedes enviar hasta {MAX_CAMPANAS_SEMANA} campañas por semana: más cansa a tus clientes.", 429
        )
    cupon = None
    if datos.cupon_id:
        cupon = get_object_or_404(Cupon, consultorio=consultorio, pk=datos.cupon_id)
        if not fidelidad.cupon_vigente(cupon):
            raise ErrorNegocio("cupon_vencido", "Ese cupón ya no está vigente.", 409)
    pacientes, con_app = _destinatarios(consultorio, datos.segmento)
    campana = Campana.objects.create(
        consultorio=consultorio,
        titulo=titulo[:80],
        mensaje=mensaje[:300],
        segmento=datos.segmento,
        cupon=cupon,
        destinatarios=len(pacientes),
        con_app=len(con_app),
    )
    if con_app:
        from django_q.tasks import async_task

        async_task(
            "clientes.avisos.enviar",
            sorted(con_app),
            f"{consultorio.nombre}: {campana.titulo}",
            campana.mensaje,
            {"tipo": "campana", "negocio": consultorio.slug},
            consultorio.pk,
        )
    extra = f"\nUsa el código {cupon.codigo} (vence el {cupon.vence_el:%d/%m})." if cupon else ""
    sin_app = [
        {
            "nombre": p.nombre,
            "celular": p.celular,
            "whatsapp_url": f"https://wa.me/{p.celular.lstrip('+')}?text="
            + quote(f"Hola {p.nombre.split()[0]}, {campana.mensaje}{extra}"),
        }
        for p in pacientes
        if p.celular not in con_app
    ]
    return 201, {"id": campana.pk, "destinatarios": len(pacientes), "con_app": len(con_app), "sin_app": sin_app}
