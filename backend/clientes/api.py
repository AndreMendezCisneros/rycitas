"""API de la app del cliente («Quiero reservar»): /cliente/v1.

Reutiliza la disponibilidad y la reserva web: la cita queda «por confirmar» y solo el negocio confirma, cancela o
mueve. El cliente no cancela desde la app: escribe al negocio por WhatsApp.
"""

import hmac
from datetime import date, datetime

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema

from agenda.models import Tratamiento
from citas import presentacion, servicios
from citas.models import Cita, Estado, Paciente
from clientes import autenticacion, fidelidad
from clientes.models import Cliente, Cupon, CuponUsado, DispositivoCliente
from consultorios.models import Consultorio
from consultorios.rubros import RUBRO_CHOICES
from denticita.errores import ErrorNegocio
from denticita.idempotencia import idempotente
from sitio.red import ip_cliente

router_sesion = Router(tags=["cliente · sesión"])
router = Router(tags=["cliente"])

NOMBRE_RUBRO = dict(RUBRO_CHOICES)


class RegistroEntrada(Schema):
    nombre: str
    correo: str
    celular: str
    referido: str = ""
    acepta_politica: bool = False
    acepta_publicidad: bool = False  # aparte y opcional (DAT-02)


class CodigoEntrada(Schema):
    correo: str
    celular: str
    codigo: str


class TokenEntrada(Schema):
    renovacion: str


class PerfilEntrada(Schema):
    nombre: str
    acepta_publicidad: bool | None = None  # None: no lo cambia


class DispositivoEntrada(Schema):
    token_fcm: str
    plataforma: str = "android"


class ReservaEntrada(Schema):
    motivo: str
    inicio: datetime
    profesional: int | None = None
    cupon: int | None = None


class VincularEntrada(Schema):
    """El enlace de una cita que el negocio mandó por WhatsApp: `/c/<token>/?v=<firma>`."""

    token: str
    firma: str = ""


def _yo(cliente: Cliente) -> dict:
    return {
        "nombre": cliente.nombre,
        "correo": cliente.correo,
        "celular": cliente.celular,
        "codigo_referido": cliente.codigo_referido,
        "invitados": cliente.referidos.count(),
        "celular_verificado": _celular_confiable(cliente),
        "verificacion_activa": settings.VERIFICAR_CLIENTES,
        "acepta_publicidad": cliente.acepta_publicidad_en is not None,
    }


def _celular_confiable(cliente: Cliente) -> bool:
    """Solo un WhatsApp probado da acceso a citas, sellos y cupones (SEG-01).

    Escribir un número no prueba que sea propio: cualquiera podría registrarse con el celular de otra persona y ver
    sus citas en todos los negocios. Se prueba abriendo el enlace firmado que el negocio envía a ese WhatsApp.
    """
    return cliente.celular_verificado_en is not None


# --- Sesión ------------------------------------------------------------------------------------------


@router_sesion.post("/registro")
def registro(request, datos: RegistroEntrada):
    if not datos.acepta_politica:
        raise ErrorNegocio("sin_consentimiento", "Debes aceptar la política de datos para continuar.", 422)
    servicios.registrar_intento_ip(ip_cliente(request))
    resultado = autenticacion.registrar(
        datos.nombre, datos.correo, datos.celular, datos.referido, acepta_publicidad=datos.acepta_publicidad
    )
    if "sesion" in resultado:
        cliente = Cliente.objects.get(correo=datos.correo.strip().lower())
        return {**resultado["sesion"], "nuevo": resultado["nuevo"], "cliente": _yo(cliente)}
    return resultado


@router_sesion.post("/verificar")
def verificar(request, datos: CodigoEntrada):
    resultado = autenticacion.verificar_codigo(datos.correo, datos.celular, datos.codigo)
    cliente = Cliente.objects.get(correo=datos.correo.strip().lower())
    return {**resultado["sesion"], "nuevo": False, "cliente": _yo(cliente)}


@router_sesion.post("/refresh")
def refresh(request, datos: TokenEntrada):
    return autenticacion.renovar(datos.renovacion)


@router_sesion.post("/logout", response={204: None})
def logout(request, datos: TokenEntrada):
    autenticacion.cerrar_sesion(datos.renovacion)
    return 204, None


# --- Perfil --------------------------------------------------------------------------------------------


@router.get("/yo")
def yo(request):
    return _yo(request.auth)


@router.put("/yo")
def editar_yo(request, datos: PerfilEntrada):
    nombre = " ".join(datos.nombre.split())
    if len(nombre) < 2:
        raise ErrorNegocio("nombre_invalido", "Escribe tu nombre.", 422)
    request.auth.nombre = nombre[:120]
    campos = ["nombre"]
    if datos.acepta_publicidad is not None:
        request.auth.acepta_publicidad_en = timezone.now() if datos.acepta_publicidad else None
        campos.append("acepta_publicidad_en")
    request.auth.save(update_fields=campos)
    return _yo(request.auth)


@router.delete("/yo", response={204: None})
def eliminar_cuenta(request):
    """Borra la cuenta de la app (derecho de cancelación; Google Play lo exige dentro de la app).

    Se borran sesiones, dispositivos y códigos, y la ficha queda anónima (no se borra la fila para no romper los
    referidos de otros). Las citas, sellos y cupones son del negocio donde se atendió: su borrado se pide al negocio,
    que lo ejecuta desde su app (pacientes → eliminar datos).
    """
    with transaction.atomic():
        cliente = Cliente.objects.select_for_update().get(pk=request.auth.pk)
        cliente.sesiones.all().delete()
        cliente.dispositivos.all().delete()
        cliente.codigos.all().delete()
        cliente.silenciados.clear()
        cliente.nombre = "Cliente eliminado"
        cliente.correo = f"eliminado-{cliente.pk}@eliminado.invalid"
        cliente.celular = f"eliminado-{cliente.pk}"
        cliente.celular_verificado_en = cliente.correo_verificado_en = None
        cliente.consentimiento_en = cliente.acepta_publicidad_en = None
        cliente.politica_version = ""
        cliente.activo = False
        cliente.save()
    return 204, None


@router.post("/dispositivos", response={204: None})
def dispositivo(request, datos: DispositivoEntrada):
    DispositivoCliente.objects.update_or_create(
        token_fcm=datos.token_fcm, defaults={"cliente": request.auth, "plataforma": datos.plataforma}
    )
    return 204, None


@router.post("/vincular")
def vincular(request, datos: VincularEntrada):
    """Abrir en la app el enlace de una cita (el que el negocio manda por WhatsApp) prueba que el número es suyo.

    Exige la firma del mensaje de WhatsApp: el token solo no prueba nada, porque quien reserva lo recibe al reservar.
    """
    servicios.registrar_intento_ip(ip_cliente(request))
    cita = Cita.objects.select_related("paciente").filter(token_gestion=datos.token).first()
    if cita is None or cita.paciente.celular != request.auth.celular:
        raise ErrorNegocio("enlace_ajeno", "Este enlace es de otro número de WhatsApp.", 409)
    if not hmac.compare_digest(datos.firma, servicios.firma_whatsapp(cita)):
        raise ErrorNegocio(
            "enlace_sin_firma", "Usa el enlace completo que te mandó el negocio por WhatsApp.", 409
        )
    if request.auth.celular_verificado_en is None:
        request.auth.celular_verificado_en = timezone.now()
        request.auth.save(update_fields=["celular_verificado_en"])
    return _yo(request.auth)


# --- Negocios ----------------------------------------------------------------------------------------


def _publicados():
    return Consultorio.objects.filter(activo=True, publicado=True)


def _negocio_resumen(c: Consultorio, celular: str | None = None) -> dict:
    datos = {
        "slug": c.slug,
        "nombre": c.nombre,
        "rubro": c.rubro,
        "rubro_nombre": NOMBRE_RUBRO.get(c.rubro, c.rubro),
        "direccion": c.direccion,
        "foto": c.foto.url if c.foto else None,
        "acepta_reservas": c.acepta_reservas,
        "fidelidad": bool(c.opciones_efectivas["fidelidad_activa"]),
    }
    if celular:
        ultima = (
            Cita.objects.filter(consultorio=c, paciente__celular=celular)
            .exclude(estado__in=[Estado.PENDIENTE, Estado.EXPIRADA])
            .order_by("-inicio")
            .first()
        )
        tarjeta = fidelidad.tarjeta(c, celular)
        datos.update(
            {
                "ultima_cita": presentacion.iso(ultima.inicio) if ultima else None,
                "sellos": tarjeta["sellos"],
                "meta": tarjeta["meta"],
                "nivel": tarjeta["nivel"]["nombre"],
                "cupones": len(fidelidad.cupones_para(c, celular)),
                "silenciado": request_silenciado(c, celular),
            }
        )
    return datos


def request_silenciado(c: Consultorio, celular: str) -> bool:
    return c.clientes_silenciados.filter(celular=celular).exists()


def _mis_consultorios(cliente: Cliente):
    if not _celular_confiable(cliente):
        return _publicados().none()
    ids = Paciente.objects.filter(celular=cliente.celular).values("consultorio_id")
    return _publicados().filter(pk__in=ids)


@router.get("/mis-negocios")
def mis_negocios(request):
    cliente = request.auth
    negocios = [_negocio_resumen(c, cliente.celular) for c in _mis_consultorios(cliente)]
    negocios.sort(key=lambda n: n["ultima_cita"] or "", reverse=True)
    return {"negocios": negocios, "celular_verificado": _celular_confiable(cliente)}


@router.get("/negocios")
def buscar(request, q: str = "", rubro: str = ""):
    consulta = _publicados().filter(suspendido=False)
    q = q.strip()
    if q:
        consulta = consulta.filter(Q(nombre__icontains=q) | Q(direccion__icontains=q) | Q(doctor_nombre__icontains=q))
    if rubro:
        consulta = consulta.filter(rubro=rubro)
    return {
        "negocios": [_negocio_resumen(c) for c in consulta.order_by("nombre")[:40]],
        "rubros": [{"clave": k, "nombre": v} for k, v in RUBRO_CHOICES],
    }


def _negocio(slug: str) -> Consultorio:
    return get_object_or_404(_publicados(), slug=slug)


@router.get("/negocios/{slug}")
def negocio(request, slug: str):
    c = _negocio(slug)
    cliente = request.auth
    es_cliente = _mis_consultorios(cliente).filter(pk=c.pk).exists()
    return {
        **presentacion.perfil_publico(c),
        "rubro_nombre": NOMBRE_RUBRO.get(c.rubro, c.rubro),
        "es_cliente": es_cliente,
        "tarjeta": fidelidad.tarjeta(c, cliente.celular) if es_cliente else None,
        "cupones": [fidelidad.cupon_publico(x) for x in fidelidad.cupones_para(c, cliente.celular)]
        if es_cliente
        else [],
        "silenciado": request_silenciado(c, cliente.celular) if es_cliente else False,
    }


@router.get("/negocios/{slug}/disponibilidad")
def disponibilidad(request, slug: str, motivo: str, desde: date | None = None, dias: int = 30, profesional: int | None = None):
    c = _negocio(slug)
    if c.suspendido:
        return {"dias": []}
    tratamiento = get_object_or_404(Tratamiento, consultorio=c, slug=motivo, reservable=True)
    if not c.opciones_efectivas["elegir_profesional"]:
        profesional = None
    resultado = servicios.consultar_disponibilidad(
        c, tratamiento, desde or timezone.localdate(), min(max(dias, 1), 60), profesional_id=profesional
    )
    return {
        "dias": [
            {"fecha": fecha.isoformat(), "horas": [presentacion.iso(h) for h in horas]} for fecha, horas in resultado.items()
        ]
    }


@router.post("/negocios/{slug}/reservas", response={201: dict})
@idempotente
def reservar(request, slug: str, datos: ReservaEntrada):
    c = _negocio(slug)
    cliente = request.auth
    if datos.inicio.tzinfo is None:
        raise ErrorNegocio("hora_invalida", "La hora debe incluir zona horaria.", 422)
    tratamiento = Tratamiento.objects.filter(consultorio=c, slug=datos.motivo).first()
    if tratamiento is None:
        raise ErrorNegocio("motivo_invalido", "Elige un servicio.", 422)
    cupon = None
    if datos.cupon is not None:
        if not _celular_confiable(cliente):
            raise ErrorNegocio("cupon_invalido", "Ese cupón ya no está disponible.", 409)
        cupon = next((x for x in fidelidad.cupones_para(c, cliente.celular) if x.pk == datos.cupon), None)
        if cupon is None:
            raise ErrorNegocio("cupon_invalido", "Ese cupón ya no está disponible.", 409)
        if cupon.tratamiento_id and cupon.tratamiento_id != tratamiento.pk:
            raise ErrorNegocio("cupon_otro_servicio", f"Este cupón es solo para {cupon.tratamiento.nombre}.", 422)
    with transaction.atomic():
        cita = servicios.crear_prerreserva(
            c, tratamiento, datos.inicio, cliente.nombre, cliente.celular, True, profesional_id=datos.profesional
        )
        if cupon is not None:
            CuponUsado.objects.create(cupon=cupon, cita=cita, celular=cliente.celular)
    return 201, {**presentacion.reserva_creada(cita), "cupon": fidelidad.cupon_publico(cupon) if cupon else None}


@router.post("/negocios/{slug}/silenciar")
def silenciar(request, slug: str, silenciar: bool = True):
    """Deja de recibir las campañas de ese negocio (los avisos de sus citas y sellos siguen llegando)."""
    c = _negocio(slug)
    if silenciar:
        request.auth.silenciados.add(c)
    else:
        request.auth.silenciados.remove(c)
    return {"silenciado": silenciar}


# --- Mis citas y beneficios ----------------------------------------------------------------------------


def _cita_cliente(cita: Cita) -> dict:
    datos = presentacion.cita_publica(cita)
    datos.pop("codigo", None)
    datos.pop("whatsapp_url", None)
    cupon = getattr(cita, "cupon_usado", None)  # el acceso inverso sin fila lanza un AttributeError
    return {
        **datos,
        "id": cita.pk,
        "negocio": {"slug": cita.consultorio.slug, "nombre": cita.consultorio.nombre},
        "enlace": f"/c/{cita.token_gestion}/",
        "cupon": fidelidad.cupon_publico(cupon.cupon) if cupon else None,
    }


@router.get("/mis-citas")
def mis_citas(request):
    cliente = request.auth
    if not _celular_confiable(cliente):
        return {"proximas": [], "pasadas": []}
    consulta = (
        Cita.objects.select_related("consultorio", "tratamiento", "profesional", "paciente", "cupon_usado__cupon")
        .filter(paciente__celular=cliente.celular, consultorio__activo=True)
        .exclude(estado__in=[Estado.PENDIENTE, Estado.EXPIRADA])
    )
    ahora = timezone.now()
    activos = [Estado.POR_APROBAR, Estado.PROGRAMADA, Estado.EN_CURSO]
    proximas = consulta.filter(estado__in=activos, fin__gte=ahora).order_by("inicio")[:30]
    pasadas = consulta.exclude(pk__in=[c.pk for c in proximas]).order_by("-inicio")[:30]
    return {"proximas": [_cita_cliente(c) for c in proximas], "pasadas": [_cita_cliente(c) for c in pasadas]}


@router.get("/beneficios")
def beneficios(request):
    """Todas las tarjetas de sellos y cupones del cliente, negocio por negocio."""
    cliente = request.auth
    tarjetas, cupones = [], []
    for c in _mis_consultorios(cliente):
        t = fidelidad.tarjeta(c, cliente.celular)
        if t["activa"]:
            tarjetas.append({"negocio": {"slug": c.slug, "nombre": c.nombre}, **t})
        for cupon in fidelidad.cupones_para(c, cliente.celular):
            cupones.append({"negocio": {"slug": c.slug, "nombre": c.nombre}, **fidelidad.cupon_publico(cupon)})
    return {"tarjetas": tarjetas, "cupones": cupones, "codigo_referido": cliente.codigo_referido}
