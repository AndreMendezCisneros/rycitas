"""API de la app del cliente («Quiero reservar»): /cliente/v1.

Reutiliza la disponibilidad y la reserva web: la cita queda «por confirmar» y solo el negocio la confirma. El cliente
cancela o mueve su cita desde la app hasta `limite_cancelacion_horas` antes; después, escribe al negocio por WhatsApp.
Al moverla, la nueva hora vuelve a quedar por confirmar.
"""

import hmac
from datetime import date, datetime

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from ninja import Router, Schema

from agenda.models import Tratamiento
from citas import presentacion, servicios
from citas.models import Cita, Estado, Paciente
from clientes import autenticacion, fidelidad, logros as gamificacion
from clientes.models import Cliente, Cupon, CuponUsado, DispositivoCliente, Seguimiento
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
    clave: str = ""
    referido: str = ""
    acepta_politica: bool = False
    acepta_publicidad: bool = False  # aparte y opcional (DAT-02)


class CodigoEntrada(Schema):
    correo: str
    celular: str
    codigo: str


class TokenEntrada(Schema):
    renovacion: str


class SalidaEntrada(Schema):
    renovacion: str
    token_fcm: str = ""  # el teléfono deja de recibir avisos


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
    notas: str = ""


class MoverEntrada(Schema):
    inicio: datetime


class SeguirEntrada(Schema):
    seguir: bool = True
    promos: bool | None = None  # None: no lo cambia


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
        datos.nombre,
        datos.correo,
        datos.celular,
        datos.clave,
        datos.referido,
        acepta_publicidad=datos.acepta_publicidad,
    )
    if "sesion" in resultado:
        cliente = Cliente.objects.get(correo=datos.correo.strip().lower())
        return {**resultado["sesion"], "nuevo": resultado["nuevo"], "cliente": _yo(cliente)}
    return resultado


class EntradaCliente(Schema):
    correo: str
    clave: str


class CambioClave(Schema):
    actual: str = ""
    nueva: str


@router_sesion.post("/entrar")
def entrar(request, datos: EntradaCliente):
    """«Ya tengo cuenta»: correo y contraseña."""
    servicios.registrar_intento_ip(ip_cliente(request))
    resultado = autenticacion.entrar(datos.correo, datos.clave)
    cliente = Cliente.objects.get(correo=datos.correo.strip().lower())
    return {**resultado["sesion"], "nuevo": False, "cliente": _yo(cliente)}


@router_sesion.post("/verificar")
def verificar(request, datos: CodigoEntrada):
    resultado = autenticacion.verificar_codigo(datos.correo, datos.celular, datos.codigo)
    cliente = Cliente.objects.get(correo=datos.correo.strip().lower())
    return {**resultado["sesion"], "nuevo": False, "cliente": _yo(cliente)}


@router_sesion.post("/refresh")
def refresh(request, datos: TokenEntrada):
    return autenticacion.renovar(datos.renovacion)


@router_sesion.post("/logout", response={204: None})
def logout(request, datos: SalidaEntrada):
    autenticacion.cerrar_sesion(datos.renovacion, datos.token_fcm)
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


@router.put("/yo/clave", response={204: None})
def cambiar_clave(request, datos: CambioClave):
    autenticacion.cambiar_clave(request.auth, datos.actual, datos.nueva)
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
                "cupones": len(fidelidad.cupones_para(c, celular, seguidor=True)),
                "silenciado": request_silenciado(c, celular),
            }
        )
    return datos


def request_silenciado(c: Consultorio, celular: str) -> bool:
    return c.clientes_silenciados.filter(celular=celular).exists()


def _mis_consultorios(cliente: Cliente):
    """Donde reservó (o el negocio le vinculó una cita) y los que sigue. Por número, solo si probó su WhatsApp."""
    filtro = Q(pk__in=Cita.objects.filter(cliente=cliente).values("consultorio_id")) | Q(
        pk__in=Seguimiento.objects.filter(cliente=cliente).values("consultorio_id")
    )
    if _celular_confiable(cliente):
        filtro |= Q(pk__in=Paciente.objects.filter(celular=cliente.celular).values("consultorio_id"))
    return _publicados().filter(filtro)


def _seguimiento(cliente: Cliente, c: Consultorio) -> Seguimiento | None:
    return Seguimiento.objects.filter(cliente=cliente, consultorio=c).first()


@router.get("/mis-negocios")
def mis_negocios(request):
    cliente = request.auth
    # Sellos y última cita salen del número: sin WhatsApp probado podrían ser de otra persona.
    celular = cliente.celular if _celular_confiable(cliente) else None
    negocios = [_negocio_resumen(c, celular) for c in _mis_consultorios(cliente)]
    negocios.sort(key=lambda n: n.get("ultima_cita") or "", reverse=True)
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
    confiable = _celular_confiable(cliente)
    seguimiento = _seguimiento(cliente, c)
    con_datos = es_cliente and confiable
    return {
        **presentacion.perfil_publico(c),
        "rubro_nombre": NOMBRE_RUBRO.get(c.rubro, c.rubro),
        "es_cliente": es_cliente,
        "tarjeta": fidelidad.tarjeta(c, cliente.celular) if con_datos else None,
        "cupones": [
            fidelidad.cupon_publico(x)
            for x in fidelidad.cupones_para(c, cliente.celular, seguidor=seguimiento is not None)
        ]
        if con_datos
        else [],
        "silenciado": request_silenciado(c, cliente.celular) if es_cliente else False,
        "siguiendo": seguimiento is not None,
        "promos": bool(seguimiento and seguimiento.promos and not request_silenciado(c, cliente.celular)),
        # La app pregunta una sola vez si quiere sus promociones: al reservar ahí por primera vez.
        "preguntar_promos": seguimiento is None,
    }


@router.post("/negocios/{slug}/seguir")
def seguir(request, slug: str, datos: SeguirEntrada):
    """Seguir al negocio y, aparte, dar o quitar el permiso de recibir sus promociones (DAT-02)."""
    c = _negocio(slug)
    cliente = request.auth
    if not datos.seguir:
        Seguimiento.objects.filter(cliente=cliente, consultorio=c).delete()
        cliente.silenciados.add(c)
        return {"siguiendo": False, "promos": False}
    seguimiento, _ = Seguimiento.objects.get_or_create(cliente=cliente, consultorio=c)
    if datos.promos is not None and seguimiento.promos != datos.promos:
        seguimiento.promos = datos.promos
        seguimiento.save(update_fields=["promos"])
    if seguimiento.promos:
        cliente.silenciados.remove(c)
    else:
        cliente.silenciados.add(c)
    return {"siguiendo": True, "promos": seguimiento.promos}


@router.get("/negocios/{slug}/disponibilidad")
def disponibilidad(request, slug: str, motivo: str, desde: date | None = None, dias: int = 30, profesional: int | None = None):
    c = _negocio(slug)
    if c.suspendido:
        return {"dias": []}
    tratamiento = get_object_or_404(Tratamiento, consultorio=c, slug=motivo, reservable=True)
    if not c.opciones_efectivas["elegir_profesional"]:
        profesional = None
    desde = desde or timezone.localdate()
    resultado = servicios.consultar_disponibilidad(c, tratamiento, desde, min(max(dias, 1), 60), profesional_id=profesional)
    hoy = timezone.localdate()
    return {
        "dias": [
            {"fecha": fecha.isoformat(), "horas": [presentacion.iso(h) for h in horas]} for fecha, horas in resultado.items()
        ],
        # Por qué hoy no aparece: la app lo explica en vez de solo mostrar el día siguiente.
        "motivo_hoy": servicios.motivo_sin_horas_hoy(c, tratamiento, profesional)
        if desde <= hoy and hoy not in resultado
        else None,
        "anticipacion_horas": c.reglas_efectivas["anticipacion_min_horas"],
        "whatsapp": c.whatsapp,
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
        seguidor = Seguimiento.objects.filter(cliente=cliente, consultorio=c).exists()
        cupon = next(
            (x for x in fidelidad.cupones_para(c, cliente.celular, seguidor=seguidor) if x.pk == datos.cupon), None
        )
        if cupon is None:
            raise ErrorNegocio("cupon_invalido", "Ese cupón ya no está disponible.", 409)
        if cupon.tratamiento_id and cupon.tratamiento_id != tratamiento.pk:
            raise ErrorNegocio("cupon_otro_servicio", f"Este cupón es solo para {cupon.tratamiento.nombre}.", 422)
    with transaction.atomic():
        cita = servicios.crear_prerreserva(
            c,
            tratamiento,
            datos.inicio,
            cliente.nombre,
            cliente.celular,
            True,
            profesional_id=datos.profesional,
            notas=datos.notas,
        )
        Cita.objects.filter(pk=cita.pk).update(cliente=cliente)
        if cupon is not None:
            CuponUsado.objects.create(cupon=cupon, cita=cita, celular=cliente.celular)
    return 201, {
        **presentacion.reserva_creada(cita),
        "cupon": fidelidad.cupon_publico(cupon) if cupon else None,
        # Primera vez con este negocio: la app pregunta si quiere sus promociones (y lo sigue).
        "preguntar_promos": not Seguimiento.objects.filter(cliente=cliente, consultorio=c).exists(),
    }


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
    activa = cita.estado in (Estado.POR_APROBAR, Estado.PROGRAMADA)
    return {
        **datos,
        "id": cita.pk,
        "negocio": {"slug": cita.consultorio.slug, "nombre": cita.consultorio.nombre, "whatsapp": cita.consultorio.whatsapp},
        "enlace": f"/c/{cita.token_gestion}/",
        "notas": cita.notas,
        "cupon": fidelidad.cupon_publico(cupon.cupon) if cupon else None,
        "motivo": cita.tratamiento.slug if cita.tratamiento_id else None,
        "profesional_id": cita.profesional_id,
        # Cancelar o mover desde la app: hasta `cambia_hasta`; después, por WhatsApp.
        "puede_cambiar": activa and servicios.puede_cambiar_cliente(cita),
        "cambia_hasta": presentacion.iso(servicios.cambia_hasta(cita)) if activa else None,
    }


def _citas_del_cliente(cliente: Cliente):
    # Lo que reservó desde la app (o le vinculó el negocio) lo ve siempre; el resto de su número, con el WhatsApp probado.
    return (
        servicios.citas_de_la_cuenta(cliente)
        .select_related("consultorio", "tratamiento", "profesional", "paciente", "cupon_usado__cupon")
        .exclude(estado__in=[Estado.PENDIENTE, Estado.EXPIRADA])
    )


@router.post("/mis-citas/{cita_id}/cancelar")
def cancelar_cita(request, cita_id: int):
    cita = servicios.cancelar_por_cliente(request.auth, cita_id)
    return _cita_cliente(cita)


@router.post("/mis-citas/{cita_id}/reprogramar")
def reprogramar_cita(request, cita_id: int, datos: MoverEntrada):
    if datos.inicio.tzinfo is None:
        raise ErrorNegocio("hora_invalida", "La hora debe incluir zona horaria.", 422)
    cita = servicios.reprogramar_por_cliente(request.auth, cita_id, datos.inicio)
    return _cita_cliente(cita)


ACTIVOS = [Estado.POR_APROBAR, Estado.PROGRAMADA, Estado.EN_CURSO]
HISTORIAL_POR_PAGINA = 20


@router.get("/mis-citas")
def mis_citas(request):
    consulta = _citas_del_cliente(request.auth)
    ahora = timezone.now()
    proximas = consulta.filter(estado__in=ACTIVOS, fin__gte=ahora).order_by("inicio")[:30]
    pasadas = consulta.exclude(pk__in=[c.pk for c in proximas]).order_by("-inicio")[:30]
    return {"proximas": [_cita_cliente(c) for c in proximas], "pasadas": [_cita_cliente(c) for c in pasadas]}


@router.get("/mis-citas/historial")
def historial(request, antes: str = "", negocio: str = ""):
    """Las citas que ya pasaron, de la más reciente a la más antigua, de 20 en 20.

    [antes]: el `inicio` de la última cita recibida, para pedir la página siguiente. [negocio]: filtra por slug.
    """
    consulta = _citas_del_cliente(request.auth).exclude(estado__in=ACTIVOS, fin__gte=timezone.now())
    todas = consulta
    if negocio:
        consulta = consulta.filter(consultorio__slug=negocio)
    if antes:
        desde = parse_datetime(antes)
        if desde is None:
            raise ErrorNegocio("fecha_invalida", "La fecha de la página no es válida.", 422)
        consulta = consulta.filter(inicio__lt=desde)
    pagina = list(consulta.order_by("-inicio", "-pk")[: HISTORIAL_POR_PAGINA + 1])
    hay_mas = len(pagina) > HISTORIAL_POR_PAGINA
    pagina = pagina[:HISTORIAL_POR_PAGINA]
    respuesta = {"citas": [_cita_cliente(c) for c in pagina], "hay_mas": hay_mas}
    if not antes:
        # Resumen y negocios para los filtros: solo en la primera página.
        negocios = {}
        for slug, nombre in todas.values_list("consultorio__slug", "consultorio__nombre").distinct():
            negocios[slug] = nombre
        respuesta["visitas"] = todas.filter(estado=Estado.TERMINADA).count()
        respuesta["negocios"] = [{"slug": k, "nombre": v} for k, v in sorted(negocios.items(), key=lambda x: x[1])]
        respuesta["completo"] = _celular_confiable(request.auth)
    return respuesta


@router.get("/logros")
def logros(request):
    """Logros, racha y nivel: el progreso del cliente en todos sus lugares."""
    return gamificacion.resumen(request.auth, _celular_confiable(request.auth))


@router.get("/beneficios")
def beneficios(request):
    """Todas las tarjetas de sellos y cupones del cliente, negocio por negocio."""
    cliente = request.auth
    confiable = _celular_confiable(cliente)
    seguidos = set(Seguimiento.objects.filter(cliente=cliente).values_list("consultorio_id", flat=True))
    tarjetas, cupones = [], []
    for c in _mis_consultorios(cliente):
        if confiable:  # los sellos se guardan por número: sin probarlo podrían ser de otra persona
            t = fidelidad.tarjeta(c, cliente.celular)
            if t["activa"]:
                tarjetas.append({"negocio": {"slug": c.slug, "nombre": c.nombre}, **t})
        elif c.pk not in seguidos:
            continue
        for cupon in fidelidad.cupones_para(c, cliente.celular, seguidor=c.pk in seguidos):
            cupones.append({"negocio": {"slug": c.slug, "nombre": c.nombre}, **fidelidad.cupon_publico(cupon)})
    return {"tarjetas": tarjetas, "cupones": cupones, "codigo_referido": cliente.codigo_referido}
