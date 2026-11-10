"""API pública del sitio. Sin cuenta: el consultorio viene en la ruta y la cita en un token (RF-14)."""
import hashlib
from datetime import date, datetime

from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Field, Router, Schema

from agenda.models import Tratamiento
from citas import presentacion, servicios
from citas.ics import generar_ics
from citas.models import Estado
from consultorios.models import Consultorio
from denticita.errores import ErrorNegocio
from denticita.idempotencia import idempotente
from mensajeria import turnstile
from sitio.models import EventoSitio
from sitio.red import ip_cliente

router = Router(tags=["público"])


class ReservaEntrada(Schema):
    motivo: str
    inicio: datetime
    nombre: str
    celular: str
    acepta_politica: bool = False
    turnstile: str = ""
    profesional: int | None = None  # None: «Cualquiera»
    precio_ofrecido: float | None = None


class EventoEntrada(Schema):
    tipo: str
    sesion: str = Field(pattern=r"^[A-Za-z0-9-]{8,40}$")


def _consultorio(slug: str) -> Consultorio:
    return get_object_or_404(Consultorio, slug=slug, activo=True, publicado=True)


def _serie_disponibilidad(resultado: dict) -> list[dict]:
    return [
        {"fecha": fecha.isoformat(), "horas": [presentacion.iso(h) for h in horas]} for fecha, horas in resultado.items()
    ]


def _exigir_zona(inicio: datetime) -> datetime:
    if inicio.tzinfo is None:
        raise ErrorNegocio("hora_invalida", "La hora debe incluir zona horaria.", 422)
    return inicio


# Rutas con "citas" primero: el subdominio «citas» está reservado, así que nunca chocan con {slug}.
@router.get("/citas/{token}")
def ver_cita(request, token: str):
    return presentacion.cita_publica(servicios.obtener_por_token(token))


@router.post("/citas/{token}/sin-whatsapp")
def sin_whatsapp(request, token: str):
    """Solo con la verificación por WhatsApp activa: deja la pre-reserva para que decida el doctor (RF-13)."""
    if not settings.VERIFICACION_WHATSAPP:
        raise ErrorNegocio("no_disponible", "Esta opción no está disponible.", 404)
    return presentacion.cita_publica(servicios.pasar_a_aprobacion(token))


@router.get("/citas/{token}/calendario.ics")
def calendario(request, token: str):
    cita = servicios.obtener_por_token(token)
    if cita.estado not in (Estado.PROGRAMADA, Estado.EN_CURSO):
        raise ErrorNegocio("sin_calendario", "Esta cita no está confirmada.", 409)
    enlace = f"{presentacion.base_url_consultorio(cita.consultorio, request)}/c/{cita.token_gestion}/"
    contenido = generar_ics(
        uid=f"cita-{cita.pk}@{settings.PLATAFORMA_DOMINIO}",
        inicio=cita.inicio,
        fin=cita.fin,
        resumen=f"Cita en {cita.consultorio.nombre}",
        ubicacion=cita.consultorio.direccion,
        descripcion=f"{cita.servicio_nombre or cita.tratamiento.nombre} con {cita.profesional.nombre}. Tu cita: {enlace}",
        secuencia=servicios.secuencia_ics(cita),
        ahora=timezone.now(),
    )
    respuesta = HttpResponse(contenido, content_type="text/calendar; charset=utf-8")
    respuesta["Content-Disposition"] = 'attachment; filename="cita.ics"'
    return respuesta


@router.get("/{slug}/perfil")
def perfil(request, slug: str, response: HttpResponse):
    response["Cache-Control"] = "public, s-maxage=300, max-age=0"
    return presentacion.perfil_publico(_consultorio(slug))


@router.get("/{slug}/disponibilidad")
def disponibilidad(
    request, slug: str, motivo: str, desde: date | None = None, dias: int = 30, profesional: int | None = None
):
    """Nunca se cachea: un cambio de horario o una reserva debe verse al instante (RF-25)."""
    consultorio = _consultorio(slug)
    if consultorio.suspendido:
        return {"dias": []}
    tratamiento = get_object_or_404(Tratamiento, consultorio=consultorio, slug=motivo, reservable=True)
    if not consultorio.opciones_efectivas["elegir_profesional"]:
        profesional = None
    resultado = servicios.consultar_disponibilidad(
        consultorio, tratamiento, desde or timezone.localdate(), dias, profesional_id=profesional
    )
    return {"dias": _serie_disponibilidad(resultado)}


@router.post("/{slug}/reservas", response={201: dict})
@idempotente
def reservar(request, slug: str, datos: ReservaEntrada):
    consultorio = _consultorio(slug)
    ip = ip_cliente(request)
    servicios.registrar_intento_ip(ip)
    turnstile.exigir_token(datos.turnstile, ip)
    tratamiento = Tratamiento.objects.filter(consultorio=consultorio, slug=datos.motivo).first()
    if tratamiento is None:
        raise ErrorNegocio("motivo_invalido", "Elige un motivo de consulta.", 422)
    cita = servicios.crear_prerreserva(
        consultorio,
        tratamiento,
        _exigir_zona(datos.inicio),
        datos.nombre,
        datos.celular,
        datos.acepta_politica,
        profesional_id=datos.profesional,
        precio_ofrecido=datos.precio_ofrecido,
    )
    return 201, presentacion.reserva_creada(cita)


@router.post("/{slug}/eventos", response={204: None})
def registrar_evento(request, slug: str, datos: EventoEntrada):
    """Medición del embudo sin cookies ni IP: solo un identificador al azar que dura lo que la pestaña."""
    if datos.tipo not in EventoSitio.Tipo.values:
        raise ErrorNegocio("evento_invalido", "Evento desconocido.", 422)
    clave = "eventos:" + hashlib.sha256(f"{settings.SECRET_KEY}{ip_cliente(request)}".encode()).hexdigest()
    cache.add(clave, 0, timeout=3600)
    if cache.incr(clave) > settings.MAX_EVENTOS_IP_HORA:
        return 204, None  # se descarta en silencio: inflar las métricas no debe ser posible ni dar pistas
    EventoSitio.objects.get_or_create(consultorio=_consultorio(slug), sesion=datos.sesion, tipo=datos.tipo)
    return 204, None
