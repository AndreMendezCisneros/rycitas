"""Reglas de negocio de una cita. Las APIs, el webhook y las tareas solo pasan por aquí."""
from __future__ import annotations

import hashlib
import hmac
import logging
import re
import secrets
from datetime import date, datetime, time, timedelta
from urllib.parse import quote

from django.conf import settings
from django.db import IntegrityError, connection, transaction
from django.db.models import F, Q
from django.utils import timezone

from agenda.models import Bloqueo, HorarioSemanal, Tratamiento
from agenda.motor import LIMA, Intervalo, ParametrosReserva, Tramo, disponibilidad, horas_libres
from citas.estimacion import CitaPlan, Estimacion, estimar_dia
from citas.models import ESTADOS_ACTIVOS, Cita, Estado, EventoCita, IntentoReserva, Origen, Paciente
from consultorios.models import Consultorio, Profesional, Usuario
from denticita import contexto
from denticita.errores import ErrorNegocio
from mensajeria import push

log = logging.getLogger(__name__)

_ALFABETO_CODIGO = "23456789ABCDEFGHJKMNPQRSTVWXYZ"  # sin caracteres que se confunden (0/O, 1/I/L, U/V)

TRANSICIONES = {
    Estado.PENDIENTE: {Estado.PROGRAMADA, Estado.POR_APROBAR, Estado.EXPIRADA, Estado.CANCELADA},
    Estado.POR_APROBAR: {Estado.PROGRAMADA, Estado.CANCELADA, Estado.EXPIRADA},
    # PROGRAMADA → TERMINADA: «Atendida» sin cronómetro (iniciar y terminar son opcionales), solo si llegó.
    Estado.PROGRAMADA: {Estado.EN_CURSO, Estado.TERMINADA, Estado.NO_ASISTIO, Estado.CANCELADA},
    Estado.EN_CURSO: {Estado.TERMINADA},
}


LLAVE_AGENDA = 4471  # espacio de nombres de los bloqueos consultivos de esta aplicación


def _horario_tomado() -> ErrorNegocio:
    return ErrorNegocio("horario_tomado", "Ese horario acaba de ocuparse. Elige otro.", 409)


# --- Datos del paciente --------------------------------------------------------------------------


def normalizar_celular(valor: str) -> str:
    """Devuelve el celular en E.164 o rechaza lo que no sea un celular peruano (RF-07)."""
    limpio = re.sub(r"[\s\-().]", "", valor or "")
    coincidencia = re.fullmatch(r"(?:\+?51)?(9\d{8})", limpio)
    if not coincidencia:
        raise ErrorNegocio("celular_invalido", "Debe ser un celular peruano de 9 dígitos que empiece con 9.", 422)
    return f"+51{coincidencia.group(1)}"


def _validar_nombre(nombre: str) -> str:
    nombre = " ".join((nombre or "").split())
    if len(nombre) < 2 or len(nombre) > 120:
        raise ErrorNegocio("nombre_invalido", "Escribe tu nombre.", 422)
    return nombre


# --- Disponibilidad ------------------------------------------------------------------------------


def parametros_de(consultorio: Consultorio, tratamiento: Tratamiento, *, para_doctor: bool = False) -> ParametrosReserva:
    reglas = consultorio.reglas_efectivas
    return ParametrosReserva(
        duracion_min=tratamiento.duracion_min,
        margen_min=max(tratamiento.margen_min, reglas["margen_entre_citas_min"]),
        # El doctor registra citas por teléfono o de último momento: sin anticipación y con más horizonte.
        anticipacion_min_horas=0 if para_doctor else reglas["anticipacion_min_horas"],
        dias_maximos=365 if para_doctor else reglas["dias_maximos"],
        paso_min=reglas["paso_min"],
    )


def tramos_de(consultorio: Consultorio, profesional: Profesional | None = None) -> list[Tramo]:
    """El horario propio del profesional; si no tiene, el del negocio."""
    filas = list(HorarioSemanal.objects.filter(consultorio=consultorio))
    propias = [h for h in filas if profesional is not None and h.profesional_id == profesional.pk]
    elegidas = propias or [h for h in filas if h.profesional_id is None]
    return [Tramo(h.dia_semana, h.hora_inicio, h.hora_fin) for h in elegidas]


def ocupados_de(
    consultorio: Consultorio,
    desde: datetime,
    hasta: datetime,
    ahora: datetime,
    excluir_cita: int | None = None,
    profesional: Profesional | None = None,
) -> list[Intervalo]:
    """Citas activas y bloqueos. Una pre-reserva vencida ya no ocupa, aunque la tarea aún no la haya marcado.

    Con `profesional`, solo su agenda y los bloqueos suyos o de todo el negocio.
    """
    citas = Cita.objects.filter(
        consultorio=consultorio, estado__in=ESTADOS_ACTIVOS, inicio__lt=hasta, fin_ocupado__gt=desde
    ).exclude(estado=Estado.PENDIENTE, expira_en__lte=ahora)
    bloqueos = Bloqueo.objects.filter(consultorio=consultorio, inicio__lt=hasta, fin__gt=desde)
    if profesional is not None:
        citas = citas.filter(profesional=profesional)
        bloqueos = bloqueos.filter(Q(profesional__isnull=True) | Q(profesional=profesional))
    ocupados = [Intervalo(i, f) for pk, i, f in citas.values_list("id", "inicio", "fin_ocupado") if pk != excluir_cita]
    ocupados += [Intervalo(i, f) for i, f in bloqueos.values_list("inicio", "fin")]
    return ocupados


def profesionales_para(
    consultorio: Consultorio, tratamiento: Tratamiento, profesional_id: int | None = None
) -> list[Profesional]:
    """Quiénes pueden atender ese servicio. Con agenda compartida, siempre el profesional principal."""
    if consultorio.opciones_efectivas["modo_agenda"] != "por_profesional":
        return [consultorio.profesional_principal()]
    candidatos = [
        p for p in consultorio.profesionales.filter(activo=True).prefetch_related("servicios") if p.hace(tratamiento)
    ]
    if profesional_id is not None:
        candidatos = [p for p in candidatos if p.pk == profesional_id]
        if not candidatos:
            raise ErrorNegocio("profesional_invalido", "Esa persona no atiende este servicio.", 422)
    if not candidatos:
        raise ErrorNegocio("sin_profesional", "Por ahora nadie atiende este servicio.", 422)
    return candidatos


def _inicio_de_dia(fecha: date) -> datetime:
    return datetime.combine(fecha, time.min, LIMA)


def consultar_disponibilidad(
    consultorio: Consultorio,
    tratamiento: Tratamiento,
    desde: date,
    dias: int = 30,
    *,
    para_doctor: bool = False,
    excluir_cita: int | None = None,
    profesional: Profesional | None = None,
    profesional_id: int | None = None,
) -> dict[date, list[datetime]]:
    """Con varios profesionales («Cualquiera»), una hora se ofrece si al menos uno está libre."""
    ahora = timezone.now()
    params = parametros_de(consultorio, tratamiento, para_doctor=para_doctor)
    dias = max(1, min(dias, params.dias_maximos))
    candidatos = [profesional] if profesional is not None else profesionales_para(consultorio, tratamiento, profesional_id)
    desde_dt = _inicio_de_dia(max(desde, timezone.localdate()))
    hasta_dt = _inicio_de_dia(max(desde, timezone.localdate()) + timedelta(days=dias))
    union: dict[date, set[datetime]] = {}
    for p in candidatos:
        ocupados = ocupados_de(consultorio, desde_dt, hasta_dt, ahora, excluir_cita, profesional=p)
        for fecha, horas in disponibilidad(desde, dias, tramos_de(consultorio, p), ocupados, params, ahora).items():
            union.setdefault(fecha, set()).update(horas)
    return {fecha: sorted(horas) for fecha, horas in sorted(union.items())}


def _turno_de_agenda(consultorio_id: int) -> None:
    """Una sola escritura de horarios a la vez por consultorio, hasta el fin de la transacción.

    Sin esto, varias inserciones simultáneas que se cruzan pueden bloquearse entre sí al revisar la restricción de
    exclusión: PostgreSQL aborta con «deadlock detected» y el paciente vería un error 500 en vez de «horario ocupado».
    La restricción sigue siendo la garantía final contra la doble reserva.
    """
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_advisory_xact_lock(%s, %s)", [LLAVE_AGENDA, consultorio_id])


def _exigir_hora_libre(
    consultorio: Consultorio,
    tratamiento: Tratamiento,
    inicio: datetime,
    *,
    para_doctor: bool = False,
    excluir_cita: int | None = None,
    profesional: Profesional | None = None,
) -> ParametrosReserva:
    """El servidor no confía en lo que mostró la pantalla: vuelve a pasar la hora por el motor."""
    if not _hora_libre_para(consultorio, tratamiento, inicio, profesional or consultorio.profesional_principal(),
                            para_doctor=para_doctor, excluir_cita=excluir_cita):
        raise _horario_tomado()
    return parametros_de(consultorio, tratamiento, para_doctor=para_doctor)


def _hora_libre_para(
    consultorio: Consultorio,
    tratamiento: Tratamiento,
    inicio: datetime,
    profesional: Profesional,
    *,
    para_doctor: bool = False,
    excluir_cita: int | None = None,
) -> bool:
    ahora = timezone.now()
    params = parametros_de(consultorio, tratamiento, para_doctor=para_doctor)
    fecha = inicio.astimezone(LIMA).date()
    if not timezone.localdate() <= fecha < timezone.localdate() + timedelta(days=params.dias_maximos):
        return False
    ocupados = ocupados_de(
        consultorio, _inicio_de_dia(fecha), _inicio_de_dia(fecha + timedelta(days=1)), ahora, excluir_cita, profesional
    )
    return inicio in horas_libres(fecha, tramos_de(consultorio, profesional), ocupados, params, ahora)


def _elegir_profesional(
    consultorio: Consultorio,
    tratamiento: Tratamiento,
    inicio: datetime,
    candidatos: list[Profesional],
    *,
    para_doctor: bool = False,
) -> Profesional:
    """Entre los libres a esa hora, el que tiene menos citas ese día: reparte el trabajo («Cualquiera»)."""
    libres = [
        p for p in candidatos if _hora_libre_para(consultorio, tratamiento, inicio, p, para_doctor=para_doctor)
    ]
    if not libres:
        raise _horario_tomado()
    if len(libres) == 1:
        return libres[0]
    fecha = inicio.astimezone(LIMA).date()
    del_dia = Cita.objects.filter(
        profesional__in=libres,
        estado__in=ESTADOS_ACTIVOS,
        inicio__gte=_inicio_de_dia(fecha),
        inicio__lt=_inicio_de_dia(fecha + timedelta(days=1)),
    )
    carga = {p.pk: 0 for p in libres}
    for pid in del_dia.values_list("profesional_id", flat=True):
        carga[pid] += 1
    return min(libres, key=lambda p: (carga[p.pk], p.orden, p.pk))


def soles(centimos: int | None) -> str:
    """«S/ 18» o «S/ 18.50»."""
    if centimos is None:
        return ""
    entero, resto = divmod(centimos, 100)
    return f"S/ {entero}" if resto == 0 else f"S/ {entero}.{resto:02d}"


def a_centimos(monto) -> int | None:
    return None if monto is None else int(round(float(monto) * 100))


def _validar_precio_ofrecido(consultorio: Consultorio, tratamiento: Tratamiento, precio: float | None) -> int | None:
    """Tipo InDrive: el cliente propone, el negocio decide al confirmar. Solo si el negocio lo tiene activo."""
    if precio is None:
        return None
    if not consultorio.opciones_efectivas["precio_ofertable"]:
        raise ErrorNegocio("precio_no_ofertable", "Este negocio no recibe ofertas de precio.", 422)
    referencia = a_centimos(tratamiento.precio_desde)
    ofrecido = a_centimos(precio)
    if referencia is None:
        raise ErrorNegocio("precio_no_ofertable", "Este servicio no tiene precio de referencia.", 422)
    if not 0 < ofrecido <= referencia * 2:
        raise ErrorNegocio(
            "precio_invalido", f"Ofrece un monto mayor que 0 y de hasta {soles(referencia * 2)}.", 422
        )
    return ofrecido


# --- Auditoría y transiciones --------------------------------------------------------------------


def _evento(cita: Cita, tipo: str, anterior: str, nuevo: str, usuario: Usuario | None = None) -> None:
    EventoCita.objects.create(
        cita=cita, tipo=tipo, valor_anterior=anterior, valor_nuevo=nuevo, usuario=usuario,
        origen=contexto.origen.get(), request_id=contexto.request_id.get(),
    )


def _cambiar_estado(cita: Cita, nuevo: str, usuario: Usuario | None = None, **campos) -> None:
    anterior = cita.estado
    if nuevo not in TRANSICIONES.get(anterior, set()):
        raise ErrorNegocio("transicion_invalida", "Esta acción ya no se puede hacer sobre la cita.", 409, estado=anterior)
    cita.estado = nuevo
    for campo, valor in campos.items():
        setattr(cita, campo, valor)
    cita.save(update_fields=["estado", *campos])
    _evento(cita, "estado", anterior, nuevo, usuario)


def _bloquear_cita(consultorio: Consultorio, cita_id: int, usuario: Usuario | None = None) -> Cita:
    """Toda acción del doctor pasa por aquí: el filtro por consultorio es lo que aísla los datos.

    Una cuenta de profesional solo actúa sobre sus citas; las de otro le responden igual que una inexistente.
    """
    citas = Cita.objects.select_for_update(of=("self",)).select_related("paciente", "tratamiento", "consultorio")
    citas = citas.filter(consultorio=consultorio, pk=cita_id)
    if usuario is not None and usuario.profesional_id:
        citas = citas.filter(profesional_id=usuario.profesional_id)
    cita = citas.first()
    if cita is None:
        raise ErrorNegocio("no_encontrada", "No encontramos esa cita.", 404)
    return cita


def _formato_hora(dt: datetime) -> str:
    return dt.astimezone(LIMA).strftime("%H:%M")


def _formato_fecha(dt: datetime) -> str:
    dias = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
    local = dt.astimezone(LIMA)
    return f"{dias[local.weekday()]} {local:%d/%m} a las {local:%H:%M}"


def _avisar_doctor(
    consultorio_id: int, tipo: str, titulo: str, cuerpo: str, cita_id: int, profesional_id: int | None = None
) -> None:
    """Aviso al profesional de la cita y a los encargados. La clave evita repetir el mismo aviso de la misma cita."""
    datos = {"tipo": tipo, "cita_id": str(cita_id)}
    transaction.on_commit(
        lambda: push.encolar(
            consultorio_id, titulo, cuerpo, datos, clave=f"{tipo}:{cita_id}", profesional_id=profesional_id
        )
    )


# --- Reserva web ---------------------------------------------------------------------------------


def registrar_intento_ip(ip: str) -> None:
    """Cuenta todo intento, también los fallidos: si no, un robot prueba sin límite (RF-18)."""
    ip_hash = hmac.new(settings.SECRET_KEY.encode(), ip.encode(), hashlib.sha256).hexdigest()
    hace_una_hora = timezone.now() - timedelta(hours=1)
    if IntentoReserva.objects.filter(ip_hash=ip_hash, creado_en__gte=hace_una_hora).count() >= settings.MAX_INTENTOS_IP_HORA:
        raise ErrorNegocio("demasiados_intentos", "Hiciste muchos intentos. Vuelve a probar en una hora.", 429)
    IntentoReserva.objects.create(ip_hash=ip_hash)


def _citas_futuras(paciente: Paciente, ahora: datetime):
    return (
        Cita.objects.filter(paciente=paciente, estado__in=ESTADOS_ACTIVOS, inicio__gt=ahora)
        .exclude(estado=Estado.PENDIENTE, expira_en__lte=ahora)
    )


def _exigir_paciente_libre(paciente: Paciente, inicio: datetime, fin: datetime, excluir_cita: int | None = None) -> None:
    """Un mismo número (paciente) no puede estar en dos citas a la vez, aunque sean con profesionales distintos.

    Se llama con el turno de agenda tomado (`_turno_de_agenda`), así dos reservas simultáneas no se cuelan.
    """
    ahora = timezone.now()
    cruce = (
        Cita.objects.filter(paciente=paciente, estado__in=ESTADOS_ACTIVOS, inicio__lt=fin, fin__gt=inicio)
        .exclude(estado=Estado.PENDIENTE, expira_en__lte=ahora)
        .exclude(pk=excluir_cita)
        .select_related("profesional")
        .first()
    )
    if cruce is not None:
        con = f" con {cruce.profesional.nombre}" if cruce.profesional_id else ""
        raise ErrorNegocio(
            "paciente_ocupado",
            f"Este número ya tiene una cita a esa hora ({_formato_hora(cruce.inicio)}{con}). Elige otro horario.",
            409,
        )


def _nuevo_codigo() -> str:
    return "DC-" + "".join(secrets.choice(_ALFABETO_CODIGO) for _ in range(5))


def _error_de_restriccion(error: IntegrityError) -> str:
    diagnostico = getattr(error.__cause__, "diag", None)
    return getattr(diagnostico, "constraint_name", "") or ""


def crear_prerreserva(
    consultorio: Consultorio,
    tratamiento: Tratamiento,
    inicio: datetime,
    nombre: str,
    celular: str,
    acepta_politica: bool,
    *,
    profesional_id: int | None = None,
    precio_ofrecido: float | None = None,
) -> Cita:
    """Retiene el horario 15 min (RF-08). Si dos llegan a la vez, la restricción de la base elige a una."""
    if not acepta_politica:
        raise ErrorNegocio("sin_consentimiento", "Debes aceptar la política de datos para reservar.", 422)
    nombre = _validar_nombre(nombre)
    celular = normalizar_celular(celular)
    if not tratamiento.reservable:
        raise ErrorNegocio("no_reservable", "Este servicio no se reserva en línea.", 422)
    if consultorio.suspendido:
        raise ErrorNegocio("suspendido", "Las reservas en línea no están disponibles por ahora.", 403)
    ofrecido = _validar_precio_ofrecido(consultorio, tratamiento, precio_ofrecido)
    if not consultorio.opciones_efectivas["elegir_profesional"]:
        profesional_id = None
    candidatos = profesionales_para(consultorio, tratamiento, profesional_id)

    ahora = timezone.now()
    with transaction.atomic():
        _turno_de_agenda(consultorio.pk)
        expirar_vencidas(consultorio)
        paciente, _ = Paciente.objects.get_or_create(
            consultorio=consultorio, celular=celular, defaults={"nombre": nombre}
        )
        if paciente.bloqueado:  # mensaje genérico: no revela el bloqueo (RF-19)
            raise ErrorNegocio(
                "no_disponible", "No pudimos completar tu reserva. Comunícate con el consultorio.", 403
            )
        if _citas_futuras(paciente, ahora).count() >= settings.MAX_CITAS_FUTURAS_POR_NUMERO:
            raise ErrorNegocio(
                "limite_citas",
                f"Este número ya tiene {settings.MAX_CITAS_FUTURAS_POR_NUMERO} citas por venir. "
                "Cancela una o comunícate con el consultorio.",
                409,
            )
        paciente.consentimiento_en = ahora
        paciente.save(update_fields=["consentimiento_en"])
        profesional = _elegir_profesional(consultorio, tratamiento, inicio, candidatos)
        params = parametros_de(consultorio, tratamiento)
        fin = inicio + timedelta(minutes=params.duracion_min)
        _exigir_paciente_libre(paciente, inicio, fin)

        # Sin la API de WhatsApp no hay verificación del paciente: la reserva retiene el horario y la confirma el
        # doctor escribiéndole desde su propio WhatsApp.
        verificar = settings.VERIFICACION_WHATSAPP
        estado = Estado.PENDIENTE if verificar else Estado.POR_APROBAR
        for _ in range(5):
            try:
                with transaction.atomic():
                    cita = Cita.objects.create(
                        consultorio=consultorio,
                        paciente=paciente,
                        tratamiento=tratamiento,
                        profesional=profesional,
                        precio_ofrecido=ofrecido,
                        inicio=inicio,
                        fin=fin,
                        fin_ocupado=fin + timedelta(minutes=params.margen_min),
                        estado=estado,
                        origen=Origen.WEB,
                        nombre_ingresado=nombre,
                        codigo=_nuevo_codigo() if verificar else "",
                        expira_en=ahora + timedelta(minutes=settings.MINUTOS_PRERRESERVA) if verificar else None,
                        token_gestion=secrets.token_urlsafe(32),
                    )
                _evento(cita, "estado", "", estado)
                if not verificar:
                    partes = [nombre, tratamiento.nombre, _formato_fecha(inicio)]
                    if consultorio.opciones_efectivas["modo_agenda"] == "por_profesional":
                        partes.insert(2, f"con {profesional.nombre}")
                    if ofrecido is not None:
                        partes.append(f"ofrece {soles(ofrecido)}")
                    _avisar_doctor(
                        consultorio.pk, "por_aprobar", "Nueva reserva por confirmar", " · ".join(partes), cita.pk,
                        profesional.pk,
                    )
                return cita
            except IntegrityError as error:
                if _error_de_restriccion(error) == "cita_codigo_unico_pendiente":
                    continue
                raise _horario_tomado() from error
    raise _horario_tomado()


def mensaje_verificacion(cita: Cita) -> str:
    return f"Hola, quiero confirmar mi cita en {cita.consultorio.nombre}. Código: {cita.codigo}"


def url_whatsapp(numero: str, texto: str) -> str:
    return f"https://wa.me/{numero.lstrip('+')}?text={quote(texto)}"


def url_verificacion(cita: Cita) -> str:
    return url_whatsapp(settings.WHATSAPP_NUMERO_PLATAFORMA, mensaje_verificacion(cita))


_PATRON_CODIGO = re.compile(r"\bDC-[A-Z0-9]{5}\b", re.IGNORECASE)


def confirmar_por_whatsapp(celular: str, texto: str) -> Cita | None:
    """Programa la cita solo si el código y el número coinciden (RF-10)."""
    coincidencia = _PATRON_CODIGO.search(texto or "")
    if not coincidencia:
        return None
    codigo = coincidencia.group(0).upper()
    ahora = timezone.now()
    with transaction.atomic():
        cita = (
            Cita.objects.select_for_update(of=("self",))
            .select_related("paciente", "consultorio", "tratamiento")
            .filter(codigo=codigo, estado=Estado.PENDIENTE)
            .first()
        )
        if cita is None:
            log.info("codigo sin pre-reserva pendiente")
            return None
        if cita.paciente.celular != celular:
            log.warning("codigo recibido desde un numero distinto; cita=%s", cita.pk)
            return None
        if cita.expira_en and cita.expira_en <= ahora:
            _cambiar_estado(cita, Estado.EXPIRADA)
            return None
        _cambiar_estado(cita, Estado.PROGRAMADA)
        paciente = cita.paciente
        paciente.verificado_en = ahora
        paciente.nombre = cita.nombre_ingresado or paciente.nombre
        paciente.save(update_fields=["verificado_en", "nombre"])
        _avisar_doctor(
            cita.consultorio_id,
            "nueva_cita",
            "Nueva cita",
            f"{paciente.nombre} · {cita.tratamiento.nombre} · {_formato_fecha(cita.inicio)}",
            cita.pk,
            cita.profesional_id,
        )
        return cita


def pasar_a_aprobacion(token: str) -> Cita:
    """Alternativa para quien no tiene WhatsApp: decide el doctor (RF-13)."""
    with transaction.atomic():
        cita = _por_token(token, bloquear=True)
        if cita.estado == Estado.PENDIENTE and cita.expira_en and cita.expira_en <= timezone.now():
            _cambiar_estado(cita, Estado.EXPIRADA)
            return cita
        _cambiar_estado(cita, Estado.POR_APROBAR, expira_en=None)
        _avisar_doctor(
            cita.consultorio_id,
            "por_aprobar",
            "Reserva por aprobar",
            f"{cita.nombre_ingresado} · {_formato_fecha(cita.inicio)}",
            cita.pk,
            cita.profesional_id,
        )
    return cita


# --- Enlace de gestión del paciente (RF-14 a RF-16) ------------------------------------------------


def _por_token(token: str, *, bloquear: bool = False) -> Cita:
    consulta = Cita.objects.select_related("paciente", "tratamiento", "consultorio")
    if bloquear:
        consulta = consulta.select_for_update(of=("self",))
    cita = consulta.filter(token_gestion=token).first()
    if cita is None:
        raise ErrorNegocio("no_encontrada", "No encontramos esta cita.", 404)
    if timezone.now() > cita.fin + timedelta(hours=24):
        raise ErrorNegocio("enlace_vencido", "Este enlace ya venció.", 410)
    return cita


def obtener_por_token(token: str) -> Cita:
    return _por_token(token)


def _mover(cita: Cita, inicio: datetime, params: ParametrosReserva, usuario: Usuario | None) -> None:
    """Un solo UPDATE: la hora anterior queda libre en el mismo instante en que se toma la nueva (RF-16)."""
    anterior = cita.inicio
    fin = inicio + timedelta(minutes=params.duracion_min)
    _exigir_paciente_libre(cita.paciente, inicio, fin, excluir_cita=cita.pk)
    cita.inicio, cita.fin = inicio, fin
    cita.fin_ocupado = fin + timedelta(minutes=params.margen_min)
    try:
        with transaction.atomic():
            cita.save(update_fields=["inicio", "fin", "fin_ocupado"])
    except IntegrityError as error:
        raise _horario_tomado() from error
    _evento(cita, "reprogramacion", anterior.isoformat(), inicio.isoformat(), usuario)


def secuencia_ics(cita: Cita) -> int:
    return cita.eventos.filter(tipo="reprogramacion").count()


# --- Acciones del doctor ---------------------------------------------------------------------------


def crear_cita_doctor(
    consultorio: Consultorio,
    usuario: Usuario,
    tratamiento: Tratamiento,
    inicio: datetime,
    nombre: str,
    celular: str,
    profesional_id: int | None = None,
) -> Cita:
    """Cita por teléfono (RF-23): sin verificación, pero con las mismas horas libres que la web."""
    nombre = _validar_nombre(nombre)
    celular = normalizar_celular(celular)
    candidatos = profesionales_para(consultorio, tratamiento, profesional_id)
    with transaction.atomic():
        _turno_de_agenda(consultorio.pk)
        expirar_vencidas(consultorio)
        paciente, creado = Paciente.objects.get_or_create(
            consultorio=consultorio, celular=celular, defaults={"nombre": nombre}
        )
        if not creado and paciente.nombre != nombre:
            paciente.nombre = nombre
            paciente.save(update_fields=["nombre"])
        profesional = _elegir_profesional(consultorio, tratamiento, inicio, candidatos, para_doctor=True)
        params = parametros_de(consultorio, tratamiento, para_doctor=True)
        fin = inicio + timedelta(minutes=params.duracion_min)
        _exigir_paciente_libre(paciente, inicio, fin)
        try:
            with transaction.atomic():
                cita = Cita.objects.create(
                    consultorio=consultorio,
                    paciente=paciente,
                    tratamiento=tratamiento,
                    profesional=profesional,
                    inicio=inicio,
                    fin=fin,
                    fin_ocupado=fin + timedelta(minutes=params.margen_min),
                    estado=Estado.PROGRAMADA,
                    origen=Origen.DOCTOR,
                    nombre_ingresado=nombre,
                    token_gestion=secrets.token_urlsafe(32),
                )
        except IntegrityError as error:
            raise _horario_tomado() from error
        _evento(cita, "estado", "", Estado.PROGRAMADA, usuario)
    return cita


def iniciar(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.inicio.astimezone(LIMA).date() != timezone.localdate():
            raise ErrorNegocio("no_es_hoy", "Solo puedes iniciar citas de hoy.", 409)
        if Cita.objects.filter(profesional_id=cita.profesional_id, estado=Estado.EN_CURSO).exclude(pk=cita.pk).exists():
            raise ErrorNegocio("otra_en_curso", "Termina la cita en curso antes de iniciar otra.", 409)
        ahora = timezone.now()
        # Si empezó, llegó: así la asistencia queda registrada aunque no se haya tocado «Llegó».
        _cambiar_estado(cita, Estado.EN_CURSO, usuario, inicio_real=ahora, llegada_en=cita.llegada_en or ahora)
    return cita


def extender(consultorio: Consultorio, usuario: Usuario, cita_id: int, minutos: int) -> Cita:
    """+10 / +20 solo mueve la estimación; no toca el rango reservado ni choca con la siguiente cita."""
    if minutos not in (10, 20):
        raise ErrorNegocio("minutos_invalidos", "Solo se puede extender 10 o 20 minutos.", 422)
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado != Estado.EN_CURSO:
            raise ErrorNegocio("transicion_invalida", "Solo se extiende una cita en curso.", 409, estado=cita.estado)
        anterior = cita.minutos_extra
        cita.minutos_extra = anterior + minutos
        cita.save(update_fields=["minutos_extra"])
        _evento(cita, "extension", str(anterior), str(cita.minutos_extra), usuario)
    return cita


MINUTOS_DEMORA = (5, 10, 15, 20, 30)


def avisar_demora(consultorio: Consultorio, usuario: Usuario, cita_id: int, minutos: int) -> Cita:
    """«Me demoro»: en curso alarga la atención; antes de iniciar corre la hora de inicio. Mueve la estimación."""
    if minutos not in MINUTOS_DEMORA:
        raise ErrorNegocio("minutos_invalidos", "Elige 5, 10, 15, 20 o 30 minutos.", 422)
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.inicio.astimezone(LIMA).date() != timezone.localdate():
            raise ErrorNegocio("no_es_hoy", "Solo se avisa la demora de citas de hoy.", 409)
        campo = {Estado.EN_CURSO: "minutos_extra", Estado.PROGRAMADA: "demora_min"}.get(cita.estado)
        if campo is None:
            raise ErrorNegocio("transicion_invalida", "Esta cita ya no está por atender.", 409, estado=cita.estado)
        anterior = getattr(cita, campo)
        # Se suma a lo que ya se estima (si ya va tarde, «+10» es 10 min desde ahora, no desde la hora original).
        estimacion = estimar_fecha(consultorio, timezone.localdate())[0].get(cita.pk)
        nuevo = anterior + minutos
        if estimacion is not None:
            if campo == "demora_min":
                objetivo = estimacion.inicio + timedelta(minutes=minutos) - cita.inicio
            else:
                objetivo = estimacion.fin + timedelta(minutes=minutos) - (cita.inicio_real or cita.inicio) - (cita.fin - cita.inicio)
            nuevo = max(nuevo, int(objetivo.total_seconds() // 60))
        setattr(cita, campo, nuevo)
        cita.save(update_fields=[campo])
        _evento(cita, "demora", str(anterior), str(nuevo), usuario)
    return cita


def avisos_de_demora(cita: Cita, base_url: str, limite: int = 4) -> list[tuple[Cita, datetime, int, str]]:
    """Los que esperan después de [cita] (y ella misma si aún no empieza), con su nueva hora y el WhatsApp listo."""
    estimaciones, _ = estimar_fecha(cita.consultorio, timezone.localdate())
    candidatas = (
        Cita.objects.filter(
            consultorio_id=cita.consultorio_id,
            profesional_id=cita.profesional_id,
            estado=Estado.PROGRAMADA,
            inicio__gte=cita.inicio,
            inicio__lt=_inicio_de_dia(timezone.localdate() + timedelta(days=1)),
        )
        .select_related("paciente", "consultorio", "tratamiento", "profesional")
        .order_by("inicio")
    )
    resultado = []
    for c in candidatas:
        estimacion = estimaciones.get(c.pk)
        if estimacion is None or estimacion.retraso_min <= 0:
            continue
        hora = hora_legible(c.inicio.astimezone(LIMA).time())
        nueva = hora_legible(estimacion.inicio.astimezone(LIMA).time())
        texto = (
            f"{_saludo(c)} Vamos con unos {estimacion.retraso_min} min de retraso: tu cita de las {hora} "
            f"empezaría cerca de las {nueva}. Disculpa la espera y gracias por tu paciencia. "
            f"Aquí ves la hora actualizada: {base_url}/c/{c.token_gestion}/"
        )
        resultado.append((c, estimacion.inicio, estimacion.retraso_min, url_whatsapp(c.paciente.celular, texto)))
        if len(resultado) >= limite:
            break
    return resultado


def terminar(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado == Estado.PROGRAMADA:
            # «Atendida» sin haber tocado «Iniciar»: cuenta como asistencia, pero no mide la duración.
            if cita.llegada_en is None:
                raise ErrorNegocio("sin_llegada", "Marca primero que llegó.", 409, estado=cita.estado)
            _cambiar_estado(cita, Estado.TERMINADA, usuario)
        else:
            _cambiar_estado(cita, Estado.TERMINADA, usuario, fin_real=timezone.now())
        from clientes import fidelidad  # sellos de la tarjeta (visita, puntualidad, referido)

        fidelidad.al_terminar(cita)
    return cita


def marcar_llegada(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    """«Llegó»: el cliente ya está en el local. Permite medir la espera (llegada → inicio)."""
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado != Estado.PROGRAMADA:
            raise ErrorNegocio("transicion_invalida", "Solo se marca la llegada de una cita programada.", 409)
        if cita.inicio.astimezone(LIMA).date() != timezone.localdate():
            raise ErrorNegocio("no_es_hoy", "Solo se marca la llegada de citas de hoy.", 409)
        cita.llegada_en = timezone.now()
        cita.save(update_fields=["llegada_en"])
        _evento(cita, "llegada", "", cita.llegada_en.isoformat(), usuario)
    return cita


def no_asistio_desde(cita: Cita) -> datetime:
    """«No vino» se puede marcar recién pasada la tolerancia del negocio (DEC-016)."""
    return cita.inicio + timedelta(minutes=cita.consultorio.opciones_efectivas["tolerancia_inasistencia_min"])


def marcar_no_asistio(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.llegada_en is not None:
            raise ErrorNegocio("ya_llego", "Esta persona ya llegó.", 409)
        if timezone.now() < no_asistio_desde(cita):
            minutos = consultorio.opciones_efectivas["tolerancia_inasistencia_min"]
            raise ErrorNegocio(
                "antes_de_tolerancia",
                f"Espera {minutos} min desde la hora de la cita antes de marcar que no vino.",
                409,
            )
        _cambiar_estado(cita, Estado.NO_ASISTIO, usuario)
        Paciente.objects.filter(pk=cita.paciente_id).update(inasistencias=F("inasistencias") + 1)
    return cita


def cancelar_por_doctor(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        _cambiar_estado(cita, Estado.CANCELADA, usuario)
    return cita


def aprobar(consultorio: Consultorio, usuario: Usuario, cita_id: int, precio_acordado: float | None = None) -> Cita:
    """Confirmar fija el precio: el que pone el encargado o, si no pone ninguno, la oferta del cliente."""
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado != Estado.POR_APROBAR:
            raise ErrorNegocio("transicion_invalida", "Esta reserva ya no está por aprobar.", 409, estado=cita.estado)
        acordado = a_centimos(precio_acordado)
        if acordado is not None and acordado <= 0:
            raise ErrorNegocio("precio_invalido", "El precio debe ser mayor que 0.", 422)
        if acordado is None:
            acordado = cita.precio_ofrecido
        _cambiar_estado(cita, Estado.PROGRAMADA, usuario, precio_acordado=acordado)
        if acordado is not None and acordado != cita.precio_ofrecido:
            _evento(cita, "precio", soles(cita.precio_ofrecido or cita.precio_referencia), soles(acordado), usuario)
    return cita


def rechazar(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado != Estado.POR_APROBAR:
            raise ErrorNegocio("transicion_invalida", "Esta reserva ya no está por aprobar.", 409, estado=cita.estado)
        _cambiar_estado(cita, Estado.CANCELADA, usuario)
    return cita


def reprogramar_por_doctor(consultorio: Consultorio, usuario: Usuario, cita_id: int, inicio: datetime) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado not in (Estado.PROGRAMADA, Estado.POR_APROBAR):
            raise ErrorNegocio("transicion_invalida", "Esta cita ya no se puede mover.", 409, estado=cita.estado)
        _turno_de_agenda(consultorio.pk)
        params = _exigir_hora_libre(
            consultorio, cita.tratamiento, inicio, para_doctor=True, excluir_cita=cita.pk, profesional=cita.profesional
        )
        _mover(cita, inicio, params, usuario)
    return cita


# --- Mensajes que el doctor envía desde su WhatsApp (sin costo) ---------------------------------------------

_DIAS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
_MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "set", "oct", "nov", "dic"]


def hora_legible(hora: time) -> str:
    """«4:20 p. m.», como se dice en Perú."""
    return f"{hora.hour % 12 or 12}:{hora.minute:02d} {'a. m.' if hora.hour < 12 else 'p. m.'}"


def fecha_legible(dt: datetime) -> str:
    """«hoy a las 4:20 p. m.», «mañana a las…» o «el lunes 9 de nov a las…»."""
    local = dt.astimezone(LIMA)
    dias = (local.date() - timezone.localdate()).days
    hora = hora_legible(local.time())
    if dias == 0:
        return f"hoy a las {hora}"
    if dias == 1:
        return f"mañana a las {hora}"
    return f"el {_DIAS[local.weekday()]} {local.day} de {_MESES[local.month - 1]} a las {hora}"


def _por_profesional(consultorio: Consultorio) -> bool:
    return consultorio.opciones_efectivas["modo_agenda"] == "por_profesional"


def _saludo(cita: Cita) -> str:
    nombre = (cita.nombre_ingresado or cita.paciente.nombre).split(" ")[0]
    if _por_profesional(cita.consultorio):  # puede escribir la recepción, no siempre quien atiende
        return f"Hola {nombre}, te escribimos de {cita.consultorio.nombre}."
    return f"Hola {nombre}, te escribe {cita.profesional.nombre} de {cita.consultorio.nombre}."


def _frase(texto: str) -> str:
    texto = texto.strip()
    return texto if not texto or texto.endswith((".", "!", "?")) else texto + "."


def hora_de_llegada(cita: Cita) -> tuple[int, str]:
    minutos = cita.consultorio.opciones_efectivas["llegar_antes_min"] or 0
    return minutos, hora_legible((cita.inicio - timedelta(minutes=minutos)).astimezone(LIMA).time())


def precio_para_mostrar(cita: Cita) -> str:
    if cita.precio_acordado is not None:
        return f"Precio acordado: {soles(cita.precio_acordado)}"
    if cita.precio_ofrecido is not None:
        return f"Tu oferta: {soles(cita.precio_ofrecido)} (por confirmar)"
    if cita.precio_referencia is not None:
        return f"Precio de referencia: {soles(cita.precio_referencia)}"
    return ""


def detalle_de_cita(cita: Cita) -> list[str]:
    """Los datos completos de la cita, una línea cada uno: van en la confirmación y en el recordatorio."""
    consultorio = cita.consultorio
    voc = consultorio.vocabulario
    duracion = cita.duracion_acordada_min or int((cita.fin - cita.inicio).total_seconds() // 60)
    lineas = [f"• {voc['servicio'].capitalize()}: {cita.servicio_nombre or cita.tratamiento.nombre} ({duracion} min)"]
    lineas.append(f"• Con: {cita.profesional.nombre}")
    precio = precio_para_mostrar(cita)
    if precio:
        lineas.append(f"• {precio}")
    direccion = consultorio.direccion
    referencias = consultorio.contenido.get("referencias")
    if referencias:
        direccion = f"{direccion} ({referencias})"
    lineas.append(f"• Dirección: {direccion}")
    if consultorio.mapa_url:
        lineas.append(f"• Mapa: {consultorio.mapa_url}")
    return lineas


def _llegada(cita: Cita) -> str:
    minutos, hora = hora_de_llegada(cita)
    return f"Te pedimos llegar {minutos} min antes, a las {hora}, por si acaso." if minutos else ""


def texto_para_paciente(cita: Cita, motivo: str, base_url: str) -> str:
    """El mensaje ya escrito para cada momento. El encargado puede editarlo en WhatsApp antes de enviarlo."""
    tratamiento = cita.servicio_nombre or cita.tratamiento.nombre
    enlace = f"{base_url}/c/{cita.token_gestion}/"
    indicaciones = _frase(cita.tratamiento.indicaciones)
    if indicaciones:
        indicaciones = " " + indicaciones
    detalle = "\n".join(detalle_de_cita(cita))
    llegada = _llegada(cita)
    cierre = " ".join(t for t in (llegada, indicaciones.strip()) if t)
    textos = {
        "confirmada": (
            f"{_saludo(cita)} Tu cita de {tratamiento} quedó confirmada para {fecha_legible(cita.inicio)}\n"
            f"{detalle}\n"
            f"{cierre + ' ' if cierre else ''}¿Nos confirmas tu asistencia? Aquí puedes ver tu cita: {enlace}"
        ),
        "rechazada": (
            f"{_saludo(cita)} Lo sentimos, no podremos atenderte {fecha_legible(cita.inicio)} "
            f"Puedes elegir otro horario aquí: {base_url}/#reservar"
        ),
        "cancelada": (
            f"{_saludo(cita)} Tu cita de {tratamiento} de {fecha_legible(cita.inicio)} fue cancelada. "
            f"Escríbenos para buscar otro horario o reserva aquí: {base_url}/#reservar"
        ),
        "horario": (
            f"{_saludo(cita)} Cambiamos nuestro horario y tu cita de {tratamiento} de {fecha_legible(cita.inicio)} "
            f"queda fuera de él. Lo sentimos. ¿Te buscamos otro horario? Respóndenos por aquí o mira tu cita: {enlace}"
        ),
        "movida": (
            f"{_saludo(cita)} Tu cita de {tratamiento} se movió para {fecha_legible(cita.inicio)}\n"
            f"{detalle}\n"
            f"{cierre + ' ' if cierre else ''}¿Te queda bien? Aquí puedes verla: {enlace}"
        ),
        "recordatorio": (
            f"{_saludo(cita)} Te recordamos tu cita de {tratamiento} {fecha_legible(cita.inicio)}\n"
            f"{detalle}\n"
            f"{cierre + ' ' if cierre else ''}¿Nos confirmas tu asistencia? {enlace}"
        ),
    }
    return textos[motivo]


def aviso_al_paciente(cita: Cita, base_url: str, motivo: str | None = None) -> str:
    """Enlace que abre el WhatsApp del doctor con el mensaje listo (RF-30, sin costo)."""
    if motivo is None:
        motivo = "cancelada" if cita.estado == Estado.CANCELADA else "confirmada"
    return url_whatsapp(cita.paciente.celular, texto_para_paciente(cita, motivo, base_url))


def siguientes_para_adelantar(cita: Cita, limite: int = 3) -> list[tuple[Cita, str]]:
    """Tras una cancelación o una inasistencia: los pacientes de ese día que podrían venir antes."""
    ahora = timezone.now()
    libre_desde = max(cita.inicio, ahora)
    fin_del_dia = _inicio_de_dia(cita.inicio.astimezone(LIMA).date() + timedelta(days=1))
    if fin_del_dia <= ahora:
        return []
    candidatas = (
        Cita.objects.filter(
            consultorio_id=cita.consultorio_id,
            profesional_id=cita.profesional_id,
            estado=Estado.PROGRAMADA,
            inicio__gt=libre_desde,
            inicio__lt=fin_del_dia,
        )
        .exclude(pk=cita.pk)
        .select_related("paciente", "consultorio", "tratamiento")
        .order_by("inicio")[:limite]
    )
    resultado = []
    for siguiente in candidatas:
        texto = (
            f"{_saludo(siguiente)} Se liberó un espacio {fecha_legible(libre_desde)} "
            f"¿Te gustaría venir antes de tu cita de las {hora_legible(siguiente.inicio.astimezone(LIMA).time())}? "
            "Respóndenos y te la adelantamos."
        )
        resultado.append((siguiente, url_whatsapp(siguiente.paciente.celular, texto)))
    return resultado


def citas_para_recordar(consultorio: Consultorio, fecha: date):
    return (
        Cita.objects.filter(
            consultorio=consultorio,
            estado=Estado.PROGRAMADA,
            inicio__gte=_inicio_de_dia(fecha),
            inicio__lt=_inicio_de_dia(fecha + timedelta(days=1)),
        )
        .select_related("paciente", "tratamiento", "consultorio")
        .order_by("inicio")
    )


def marcar_recordatorio(consultorio: Consultorio, usuario: Usuario, cita_id: int) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        cita.recordatorio_enviado_en = timezone.now()
        cita.save(update_fields=["recordatorio_enviado_en"])
        _evento(cita, "recordatorio", "", cita.recordatorio_enviado_en.isoformat(), usuario)
    return cita


def marcar_asistencia(consultorio: Consultorio, usuario: Usuario, cita_id: int, confirmada: bool | None) -> Cita:
    with transaction.atomic():
        cita = _bloquear_cita(consultorio, cita_id, usuario)
        if cita.estado != Estado.PROGRAMADA:
            raise ErrorNegocio("transicion_invalida", "Solo se marca la asistencia de una cita programada.", 409)
        anterior = cita.asistencia_confirmada
        cita.asistencia_confirmada = confirmada
        cita.save(update_fields=["asistencia_confirmada"])
        _evento(cita, "asistencia", str(anterior), str(confirmada), usuario)
    return cita


# --- Estimación del día ------------------------------------------------------------------------------


def _ahora_para(fecha: date) -> datetime | None:
    hoy = timezone.localdate()
    return timezone.now() if fecha == hoy else None


def estimar_fecha(consultorio: Consultorio, fecha: date) -> tuple[dict[int, Estimacion], int]:
    citas = Cita.objects.filter(
        consultorio=consultorio,
        inicio__gte=_inicio_de_dia(fecha),
        inicio__lt=_inicio_de_dia(fecha + timedelta(days=1)),
        estado__in=[Estado.PROGRAMADA, Estado.EN_CURSO, Estado.TERMINADA],
    )
    planes: dict[int, list[CitaPlan]] = {}
    for c in citas:
        planes.setdefault(c.profesional_id, []).append(
            CitaPlan(
                c.pk, c.estado, c.inicio, c.fin, c.fin_ocupado, c.minutos_extra, c.inicio_real, c.fin_real,
                c.demora_min,
            )
        )
    # Cada profesional lleva su propio retraso; el del negocio es el mayor.
    estimaciones: dict[int, Estimacion] = {}
    retraso = 0
    for plan in planes.values():
        parcial, r = estimar_dia(plan, _ahora_para(fecha))
        estimaciones.update(parcial)
        retraso = max(retraso, r)
    if not planes:
        return estimar_dia([], _ahora_para(fecha))
    return estimaciones, retraso


def citas_de_rango(
    consultorio: Consultorio, desde: date, hasta_exclusivo: date, profesional: Profesional | None = None
):
    filtro = {"profesional": profesional} if profesional is not None else {}
    return (
        Cita.objects.filter(
            consultorio=consultorio,
            inicio__gte=_inicio_de_dia(desde),
            inicio__lt=_inicio_de_dia(hasta_exclusivo),
            **filtro,
        )
        .filter(Q(estado__in=[Estado.PROGRAMADA, Estado.EN_CURSO, Estado.TERMINADA, Estado.NO_ASISTIO, Estado.POR_APROBAR]))
        .select_related("paciente", "tratamiento", "profesional")
    )


# --- Tareas programadas --------------------------------------------------------------------------------


def expirar_vencidas(consultorio: Consultorio | None = None) -> int:
    """Libera pre-reservas sin verificar (RF-11) y solicitudes por aprobar cuya hora ya pasó."""
    ahora = timezone.now()
    vencidas = Cita.objects.filter(
        Q(estado=Estado.PENDIENTE, expira_en__lte=ahora) | Q(estado=Estado.POR_APROBAR, inicio__lte=ahora)
    )
    if consultorio is not None:
        vencidas = vencidas.filter(consultorio=consultorio)
    total = 0
    with transaction.atomic():
        for cita in vencidas.select_for_update(skip_locked=True):
            _cambiar_estado(cita, Estado.EXPIRADA)
            total += 1
    return total


def anonimizar_paciente(paciente: Paciente) -> None:
    """Borrado a pedido (RNF-09). Conserva las citas para las estadísticas, sin datos personales."""
    from mensajeria.models import MensajeEntrante

    with transaction.atomic():
        MensajeEntrante.objects.filter(celular=paciente.celular.lstrip("+")).delete()
        paciente.citas.update(nombre_ingresado="")
        paciente.nombre = "Paciente eliminado"
        paciente.celular = f"eliminado-{paciente.pk}"
        paciente.verificado_en = None
        paciente.consentimiento_en = None
        paciente.save()
