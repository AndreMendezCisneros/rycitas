"""API de la app del doctor. Todo se filtra por `request.auth.consultorio` (RNF-08)."""
from datetime import date, datetime, timedelta

from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema

from agenda.models import Bloqueo, Tratamiento
from agenda.motor import LIMA, Intervalo, huecos_del_dia
from citas import presentacion, servicios
from citas.models import Cita, Estado, Paciente
from consultorios.models import Profesional, turnos_con_rango, validar_turnos
from denticita.errores import ErrorNegocio
from denticita.idempotencia import idempotente

router = Router(tags=["agenda"])


class CitaEntrada(Schema):
    tratamiento_id: int
    inicio: datetime
    nombre: str
    celular: str
    profesional_id: int | None = None


class AprobarEntrada(Schema):
    precio_acordado: float | None = None


class ExtenderEntrada(Schema):
    minutos: int


class MoverEntrada(Schema):
    inicio: datetime


class BloquearEntrada(Schema):
    bloqueado: bool = True


class AsistenciaEntrada(Schema):
    confirmada: bool | None


class AvisosEntrada(Schema):
    apagados: list[str] = []
    recordar_cita_min: int | None = None


class TurnoEntrada(Schema):
    nombre: str
    hasta: str = ""


class TurnosEntrada(Schema):
    turnos: list[TurnoEntrada]


def _filtro_profesional(request, profesional: int | None) -> Profesional | None:
    """Sin parámetro: la agenda propia de la cuenta (o todo, si la cuenta no es de un profesional). 0: todos.

    Una cuenta de profesional siempre ve solo su agenda, pida lo que pida: «Todos» es de la cuenta general.
    """
    if request.auth.profesional_id or profesional is None:
        return request.auth.profesional
    if profesional == 0:
        return None
    return get_object_or_404(Profesional, consultorio=request.auth.consultorio, pk=profesional)


def _por_aprobar(consultorio, profesional: Profesional | None = None):
    citas = Cita.objects.filter(consultorio=consultorio, estado=Estado.POR_APROBAR)
    return citas.filter(profesional=profesional) if profesional is not None else citas


def _turnos_del_dia(consultorio, citas: list[Cita]) -> list[dict]:
    """Los turnos del negocio con cuántas citas y cuántas por confirmar tiene cada uno ese día."""
    turnos = turnos_con_rango(consultorio.opciones_efectivas["turnos"])
    for t in turnos:
        t.update(citas=0, por_confirmar=0)
    for c in citas:
        local = c.inicio.astimezone(LIMA)
        minuto = local.hour * 60 + local.minute
        turno = next((t for t in turnos if t["desde"] <= minuto < t["hasta"]), turnos[-1])
        turno["citas"] += 1
        turno["por_confirmar"] += c.estado == Estado.POR_APROBAR
    return turnos


def _agenda(consultorio, fecha: date, profesional: Profesional | None = None) -> dict:
    citas = list(servicios.citas_de_rango(consultorio, fecha, fecha + timedelta(days=1), profesional))
    estimaciones, retraso = servicios.estimar_fecha(consultorio, fecha)
    ahora = timezone.now()
    # Los huecos son de una agenda: con varios profesionales y «Todos» no hay un hueco único que mostrar.
    agenda_de = profesional
    if agenda_de is None and consultorio.opciones_efectivas["modo_agenda"] != "por_profesional":
        agenda_de = consultorio.profesional_principal()
    huecos = []
    if agenda_de is not None:
        ocupados = servicios.ocupados_de(
            consultorio,
            servicios._inicio_de_dia(fecha),
            servicios._inicio_de_dia(fecha + timedelta(days=1)),
            ahora,
            profesional=agenda_de,
        )
        huecos = huecos_del_dia(fecha, servicios.tramos_de(consultorio, agenda_de), ocupados)
    if fecha == timezone.localdate():  # el tiempo que ya pasó no es un hueco aprovechable
        huecos = [Intervalo(max(h.inicio, ahora), h.fin) for h in huecos if h.fin > ahora]
    return {
        "fecha": fecha.isoformat(),
        "retraso_min": retraso,
        "por_aprobar": _por_aprobar(consultorio, profesional).count(),
        "turnos": _turnos_del_dia(consultorio, citas),
        "citas": [presentacion.cita_doctor(c, estimaciones.get(c.pk)) for c in citas],
        "huecos": [{"inicio": presentacion.iso(h.inicio), "fin": presentacion.iso(h.fin)} for h in huecos],
        "generado_en": presentacion.iso(ahora),
    }


def _tras_accion(request, cita: Cita) -> dict:
    """Devuelve el día ya recalculado para que la app no necesite una segunda llamada (RF-22)."""
    return {
        "cita_id": cita.pk,
        "agenda": _agenda(request.auth.consultorio, timezone.localdate(), request.auth.profesional),
    }


def _siguientes(cita: Cita) -> list[dict]:
    return [
        {"cita_id": s.pk, "paciente": s.paciente.nombre, "inicio": presentacion.iso(s.inicio), "whatsapp_url": url}
        for s, url in servicios.siguientes_para_adelantar(cita)
    ]


def _con_aviso(request, cita: Cita, motivo: str | None = None) -> dict:
    consultorio = request.auth.consultorio
    return {
        "cita_id": cita.pk,
        "estado": cita.estado,
        "whatsapp_url": servicios.aviso_al_paciente(cita, presentacion.base_url_consultorio(consultorio, request), motivo),
        "siguientes": _siguientes(cita) if cita.estado in (Estado.CANCELADA, Estado.NO_ASISTIO) else [],
        "agenda": _agenda(consultorio, timezone.localdate(), request.auth.profesional),
    }


def _zona(inicio: datetime) -> datetime:
    if inicio.tzinfo is None:
        raise ErrorNegocio("hora_invalida", "La hora debe incluir zona horaria.", 422)
    return inicio


def _tratamiento(request, tratamiento_id: int) -> Tratamiento:
    return get_object_or_404(Tratamiento, consultorio=request.auth.consultorio, pk=tratamiento_id)


# --- Agenda ------------------------------------------------------------------------------------------


@router.get("/agenda")
def agenda(request, fecha: date | None = None, profesional: int | None = None):
    return _agenda(request.auth.consultorio, fecha or timezone.localdate(), _filtro_profesional(request, profesional))


def _bloqueos_de(consultorio, desde: date, hasta: date, profesional: Profesional | None):
    bloqueos = Bloqueo.objects.filter(
        consultorio=consultorio, inicio__lt=servicios._inicio_de_dia(hasta), fin__gt=servicios._inicio_de_dia(desde)
    )
    if profesional is not None:
        bloqueos = bloqueos.filter(Q(profesional__isnull=True) | Q(profesional=profesional))
    return bloqueos


@router.get("/agenda/semana")
def semana(request, desde: date | None = None, profesional: int | None = None):
    consultorio = request.auth.consultorio
    filtro = _filtro_profesional(request, profesional)
    desde = desde or timezone.localdate()
    hasta = desde + timedelta(days=7)
    citas = list(servicios.citas_de_rango(consultorio, desde, hasta, filtro))
    bloqueos = _bloqueos_de(consultorio, desde, hasta, filtro)
    dias = []
    for n in range(7):
        fecha = desde + timedelta(days=n)
        inicio_dia = servicios._inicio_de_dia(fecha)
        fin_dia = inicio_dia + timedelta(days=1)
        del_dia = [c for c in citas if inicio_dia <= c.inicio < fin_dia]
        dias.append(
            {
                "fecha": fecha.isoformat(),
                "citas": [presentacion.cita_doctor(c) for c in del_dia],
                "turnos": _turnos_del_dia(consultorio, del_dia),
                "bloqueos": [
                    {"id": b.pk, "inicio": presentacion.iso(b.inicio), "fin": presentacion.iso(b.fin), "motivo": b.motivo}
                    for b in bloqueos
                    if b.inicio < fin_dia and b.fin > inicio_dia
                ],
            }
        )
    return {"desde": desde.isoformat(), "dias": dias}


# --- Citas -------------------------------------------------------------------------------------------


@router.get("/citas/disponibilidad")
def disponibilidad(
    request,
    tratamiento_id: int,
    desde: date | None = None,
    dias: int = 14,
    excluir_cita: int | None = None,
    profesional: int | None = None,
):
    """Horas libres para la cita por teléfono (RF-23) o para mover una cita existente (RF-30).

    Al mover, siempre en la agenda del mismo profesional de la cita.
    """
    consultorio = request.auth.consultorio
    elegido = None
    propio = request.auth.profesional
    if excluir_cita is not None:
        filtro = {"profesional": propio} if propio is not None else {}
        elegido = get_object_or_404(Cita, consultorio=consultorio, pk=excluir_cita, **filtro).profesional
    elif propio is not None:
        elegido = propio
    elif profesional:
        elegido = get_object_or_404(Profesional, consultorio=consultorio, pk=profesional)
    resultado = servicios.consultar_disponibilidad(
        consultorio,
        _tratamiento(request, tratamiento_id),
        desde or timezone.localdate(),
        dias,
        para_doctor=True,
        excluir_cita=excluir_cita,
        profesional=elegido,
    )
    return {
        "dias": [
            {"fecha": f.isoformat(), "horas": [presentacion.iso(h) for h in horas]} for f, horas in resultado.items()
        ]
    }


@router.get("/citas/por-aprobar")
def por_aprobar(request):
    citas = (
        _por_aprobar(request.auth.consultorio, request.auth.profesional)
        .select_related("paciente", "tratamiento", "profesional")
        .order_by("inicio")
    )
    return {"citas": [presentacion.cita_doctor(c) for c in citas]}


@router.post("/citas", response={201: dict})
@idempotente
def crear(request, datos: CitaEntrada):
    cita = servicios.crear_cita_doctor(
        request.auth.consultorio,
        request.auth,
        _tratamiento(request, datos.tratamiento_id),
        _zona(datos.inicio),
        datos.nombre,
        datos.celular,
        # Una cuenta de profesional solo agenda en su propia agenda.
        request.auth.profesional_id or datos.profesional_id,
    )
    # Sin este aviso, quien reservó por teléfono no recibiría nunca su enlace ni su calendario.
    return 201, _con_aviso(request, cita)


@router.post("/citas/{cita_id}/iniciar")
@idempotente
def iniciar(request, cita_id: int):
    return _tras_accion(request, servicios.iniciar(request.auth.consultorio, request.auth, cita_id))


@router.post("/citas/{cita_id}/extender")
@idempotente
def extender(request, cita_id: int, datos: ExtenderEntrada):
    return _tras_accion(request, servicios.extender(request.auth.consultorio, request.auth, cita_id, datos.minutos))


@router.post("/citas/{cita_id}/demora")
@idempotente
def demora(request, cita_id: int, datos: ExtenderEntrada):
    """«Me demoro N min»: corre la estimación y devuelve a quiénes avisar, con su WhatsApp ya escrito."""
    cita = servicios.avisar_demora(request.auth.consultorio, request.auth, cita_id, datos.minutos)
    base = presentacion.base_url_consultorio(request.auth.consultorio, request)
    avisos = [
        {
            "cita_id": c.pk,
            "paciente": c.paciente.nombre,
            "inicio": presentacion.iso(c.inicio),
            "inicio_estimado": presentacion.iso(estimado),
            "retraso_min": retraso,
            "whatsapp_url": url,
        }
        for c, estimado, retraso, url in servicios.avisos_de_demora(cita, base)
    ]
    return {**_tras_accion(request, cita), "avisos": avisos}


@router.post("/citas/{cita_id}/terminar")
@idempotente
def terminar(request, cita_id: int):
    return _tras_accion(request, servicios.terminar(request.auth.consultorio, request.auth, cita_id))


@router.post("/citas/{cita_id}/llego")
@idempotente
def llego(request, cita_id: int):
    return _tras_accion(request, servicios.marcar_llegada(request.auth.consultorio, request.auth, cita_id))


@router.post("/citas/{cita_id}/no-asistio")
@idempotente
def no_asistio(request, cita_id: int):
    cita = servicios.marcar_no_asistio(request.auth.consultorio, request.auth, cita_id)
    return {**_tras_accion(request, cita), "siguientes": _siguientes(cita)}


@router.post("/citas/{cita_id}/cancelar")
@idempotente
def cancelar(request, cita_id: int):
    return _con_aviso(request, servicios.cancelar_por_doctor(request.auth.consultorio, request.auth, cita_id))


@router.post("/citas/{cita_id}/aprobar")
@idempotente
def aprobar(request, cita_id: int, datos: AprobarEntrada | None = None):
    precio = datos.precio_acordado if datos else None
    cita = servicios.aprobar(request.auth.consultorio, request.auth, cita_id, precio)
    return _con_aviso(request, cita, "confirmada")


@router.post("/citas/{cita_id}/rechazar")
@idempotente
def rechazar(request, cita_id: int):
    return _con_aviso(request, servicios.rechazar(request.auth.consultorio, request.auth, cita_id), "rechazada")


@router.post("/citas/{cita_id}/reprogramar")
@idempotente
def reprogramar(request, cita_id: int, datos: MoverEntrada):
    cita = servicios.reprogramar_por_doctor(request.auth.consultorio, request.auth, cita_id, _zona(datos.inicio))
    return _con_aviso(request, cita, "movida")


@router.get("/citas/recordatorios")
def recordatorios(request, fecha: date | None = None, profesional: int | None = None):
    """Por defecto, las citas de mañana: el doctor las recuerda con un toque desde su WhatsApp."""
    consultorio = request.auth.consultorio
    filtro = _filtro_profesional(request, profesional)
    fecha = fecha or timezone.localdate() + timedelta(days=1)
    base = presentacion.base_url_consultorio(consultorio, request)
    citas = servicios.citas_para_recordar(consultorio, fecha)
    if filtro is not None:
        citas = citas.filter(profesional=filtro)
    return {
        "fecha": fecha.isoformat(),
        "citas": [
            {**presentacion.cita_doctor(c), "whatsapp_url": servicios.aviso_al_paciente(c, base, "recordatorio")}
            for c in citas
        ],
    }


@router.post("/citas/{cita_id}/recordado")
def recordado(request, cita_id: int):
    return presentacion.cita_doctor(servicios.marcar_recordatorio(request.auth.consultorio, request.auth, cita_id))


@router.post("/citas/{cita_id}/asistencia")
def asistencia(request, cita_id: int, datos: AsistenciaEntrada):
    cita = servicios.marcar_asistencia(request.auth.consultorio, request.auth, cita_id, datos.confirmada)
    return presentacion.cita_doctor(cita)


@router.get("/agenda/mes")
def mes(request, anio: int, mes: int, profesional: int | None = None):
    """Cuántas citas y bloqueos tiene cada día del mes, para la vista de calendario."""
    if not 1 <= mes <= 12 or not 2000 <= anio <= 2100:
        raise ErrorNegocio("fecha_invalida", "Mes no válido.", 422)
    consultorio = request.auth.consultorio
    filtro = _filtro_profesional(request, profesional)
    desde = date(anio, mes, 1)
    hasta = date(anio + (mes == 12), mes % 12 + 1, 1)
    conteo: dict[str, dict] = {}
    for c in servicios.citas_de_rango(consultorio, desde, hasta, filtro):
        dia = conteo.setdefault(c.inicio.astimezone(LIMA).date().isoformat(), {"citas": 0, "por_confirmar": 0})
        dia["citas"] += 1
        dia["por_confirmar"] += c.estado == Estado.POR_APROBAR
    bloqueados = set()
    for b in _bloqueos_de(consultorio, desde, hasta, filtro):
        dia = max(b.inicio.astimezone(LIMA).date(), desde)
        while dia < hasta and servicios._inicio_de_dia(dia) < b.fin:
            bloqueados.add(dia.isoformat())
            dia += timedelta(days=1)
    dias = []
    dia = desde
    while dia < hasta:
        clave = dia.isoformat()
        dias.append({"fecha": clave, **conteo.get(clave, {"citas": 0, "por_confirmar": 0}), "bloqueo": clave in bloqueados})
        dia += timedelta(days=1)
    return {"anio": anio, "mes": mes, "dias": dias}


# --- Pacientes ---------------------------------------------------------------------------------------


def _paciente(p: Paciente) -> dict:
    return {
        "id": p.pk,
        "nombre": p.nombre,
        "celular": p.celular,
        "inasistencias": p.inasistencias,
        "bloqueado": p.bloqueado,
        "verificado": p.verificado_en is not None,
    }


@router.get("/pacientes")
def pacientes(request, q: str = ""):
    consulta = Paciente.objects.filter(consultorio=request.auth.consultorio)
    # Una pre-reserva sin verificar no es todavía un paciente del consultorio.
    consulta = consulta.annotate(
        confirmadas=Count("citas", filter=~Q(citas__estado__in=[Estado.PENDIENTE, Estado.EXPIRADA]))
    ).filter(confirmadas__gt=0)
    q = q.strip()
    if q:
        digitos = "".join(ch for ch in q if ch.isdigit())
        filtro = Q(nombre__icontains=q)
        if len(digitos) >= 3:
            filtro |= Q(celular__contains=digitos)
        consulta = consulta.filter(filtro)
    return {"pacientes": [_paciente(p) for p in consulta.order_by("nombre")[:50]]}


@router.get("/pacientes/{paciente_id}")
def paciente_detalle(request, paciente_id: int):
    p = get_object_or_404(Paciente, consultorio=request.auth.consultorio, pk=paciente_id)
    citas = p.citas.select_related("tratamiento", "paciente").exclude(estado=Estado.PENDIENTE).order_by("-inicio")[:50]
    return {**_paciente(p), "citas": [presentacion.cita_doctor(c) for c in citas]}


@router.post("/pacientes/{paciente_id}/bloquear")
def bloquear(request, paciente_id: int, datos: BloquearEntrada):
    p = get_object_or_404(Paciente, consultorio=request.auth.consultorio, pk=paciente_id)
    p.bloqueado = datos.bloqueado
    p.save(update_fields=["bloqueado"])
    return _paciente(p)


# --- Negocio -----------------------------------------------------------------------------------------


@router.get("/metricas")
def metricas(request, anio: int | None = None, mes: int | None = None):
    """Tablero «Mi mes» (mejora 9): los indicadores del mes y del anterior para comparar."""
    from sitio.metricas import kpis

    hoy = timezone.localdate()
    anio, mes = anio or hoy.year, mes or hoy.month
    if not 1 <= mes <= 12 or not 2020 <= anio <= 2100:
        raise ErrorNegocio("mes_invalido", "Mes no válido.", 422)
    desde = date(anio, mes, 1)
    hasta = date(anio + (mes == 12), mes % 12 + 1, 1)
    anterior = date(desde.year - (desde.month == 1), (desde.month - 2) % 12 + 1, 1)
    consultorio = request.auth.consultorio
    return {
        "anio": anio,
        "mes": mes,
        "actual": kpis(consultorio, desde, hasta),
        "anterior": kpis(consultorio, anterior, desde),
    }


@router.get("/negocio")
def negocio(request):
    """Todo lo que la app necesita para hablar como el negocio: «cliente» o «paciente», «barbero» o «doctor»."""
    consultorio = request.auth.consultorio
    opciones = consultorio.opciones_efectivas
    return {
        "nombre": consultorio.nombre,
        "slug": consultorio.slug,
        "rubro": consultorio.rubro,
        "rubro_nombre": consultorio.tipo["nombre"],
        "color": consultorio.contenido.get("color_acento") or consultorio.tipo["color"],
        "vocabulario": consultorio.vocabulario,
        "sitio_url": presentacion.base_url_consultorio(consultorio, request),
        "suspendido": consultorio.suspendido,
        "opciones": {
            "modo_agenda": opciones["modo_agenda"],
            "precio_ofertable": opciones["precio_ofertable"],
            "adelantos": opciones["adelantos"],
            "llegar_antes_min": opciones["llegar_antes_min"],
            "tolerancia_inasistencia_min": opciones["tolerancia_inasistencia_min"],
            "turnos": opciones["turnos"],
        },
        "profesionales": [
            # servicios vacío: hace todos (igual que en la reserva web).
            {"id": p.pk, "nombre": p.nombre, "detalle": p.detalle, "servicios": [s.pk for s in p.servicios.all()]}
            for p in consultorio.profesionales.filter(activo=True).prefetch_related("servicios")
        ],
        "cuenta": {
            "correo": request.auth.correo,
            "nombre": request.auth.nombre,
            "profesional_id": request.auth.profesional_id,
            "es_general": request.auth.profesional_id is None,
        },
    }


def _avisos(request) -> dict:
    from consultorios.models import TIPOS_DE_AVISO

    apagados = set(request.auth.avisos_apagados or [])
    return {
        "tipos": [{"tipo": t, "nombre": n, "activo": t not in apagados} for t, n in TIPOS_DE_AVISO.items()],
        "recordar_cita_min": request.auth.consultorio.opciones_efectivas["recordar_cita_min"],
        "puede_cambiar_minutos": request.auth.profesional_id is None,
    }


@router.get("/avisos")
def avisos(request):
    """Qué notificaciones recibe esta cuenta y cuántos minutos antes de cada cita avisa el negocio."""
    return _avisos(request)


@router.put("/avisos")
def guardar_avisos(request, datos: AvisosEntrada):
    from consultorios.models import TIPOS_DE_AVISO

    usuario = request.auth
    usuario.avisos_apagados = sorted({t for t in datos.apagados if t in TIPOS_DE_AVISO})
    usuario.save(update_fields=["avisos_apagados"])
    if datos.recordar_cita_min is not None:
        if usuario.profesional_id:
            raise ErrorNegocio("solo_general", "Solo la cuenta general cambia el aviso antes de cada cita.", 403)
        if datos.recordar_cita_min not in (0, 10, 15, 30, 60):
            raise ErrorNegocio("minutos_invalidos", "Elige 10, 15, 30 o 60 minutos, o apágalo.", 422)
        consultorio = usuario.consultorio
        consultorio.opciones = {**(consultorio.opciones or {}), "recordar_cita_min": datos.recordar_cita_min}
        consultorio.save(update_fields=["opciones"])
    return _avisos(request)


@router.put("/turnos")
def guardar_turnos(request, datos: TurnosEntrada):
    """Turnos en que se divide la agenda del día. Solo la cuenta general cambia la configuración del negocio."""
    if request.auth.profesional_id:
        raise ErrorNegocio("solo_general", "Solo la cuenta general del negocio puede cambiar los turnos.", 403)
    try:
        turnos = validar_turnos([t.dict() for t in datos.turnos])
    except ValueError as error:
        raise ErrorNegocio("turnos_invalidos", str(error), 422) from None
    consultorio = request.auth.consultorio
    consultorio.opciones = {**(consultorio.opciones or {}), "turnos": turnos}
    consultorio.save(update_fields=["opciones"])
    return {"turnos": turnos}
