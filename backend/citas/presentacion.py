"""Convierte citas y consultorios al JSON que consumen el sitio y la app. Fechas siempre en hora de Lima."""
from __future__ import annotations

from datetime import datetime

from django.conf import settings
from django.utils import timezone

from agenda.models import HorarioSemanal, Tratamiento
from agenda.motor import LIMA
from citas import servicios
from citas.estimacion import Estimacion
from citas.models import Cita, Estado
from consultorios.models import Consultorio, Profesional


def iso(dt: datetime | None) -> str | None:
    return dt.astimezone(LIMA).isoformat(timespec="seconds") if dt else None


def tratamiento_publico(t: Tratamiento) -> dict:
    return {
        "slug": t.slug,
        "nombre": t.nombre,
        "motivo": t.motivo_paciente or t.nombre,
        "descripcion": t.descripcion,
        "duracion_min": t.duracion_min,
        "precio_desde": str(t.precio_desde) if t.precio_desde is not None else None,
        "reservable": t.reservable,
    }


hora_legible = servicios.hora_legible  # RWN-11: el mismo formato en el sitio y en los mensajes


def profesional_publico(p: Profesional) -> dict:
    servicios_ids = [t.slug for t in p.servicios.all()]
    return {
        "id": p.pk,
        "nombre": p.nombre,
        "detalle": p.detalle,
        "foto": p.foto.url if p.foto else None,
        "iniciales": p.iniciales,
        "servicios": servicios_ids or None,  # None: hace todos
    }


def opciones_publicas(consultorio: Consultorio) -> dict:
    """Solo lo que el sitio necesita saber; el resto de las opciones queda en el servidor."""
    o = consultorio.opciones_efectivas
    return {
        "elegir_profesional": o["elegir_profesional"],
        "precio_ofertable": o["precio_ofertable"],
        "llegar_antes_min": o["llegar_antes_min"],
        "sesion_web_min": o["sesion_web_min"],
    }


def precios(cita: Cita) -> dict:
    return {
        "precio_referencia": cita.precio_referencia,
        "precio_ofrecido": cita.precio_ofrecido,
        "precio_acordado": cita.precio_acordado,
        "precio_texto": servicios.precio_para_mostrar(cita),
    }


def llegada(cita: Cita) -> dict:
    minutos, hora = servicios.hora_de_llegada(cita)
    return {"llegar_antes_min": minutos, "hora_llegada": hora if minutos else None}


def horario_publico(consultorio: Consultorio) -> list[dict]:
    """`tramos` es el texto para leer; `rangos` son los datos con los que el navegador calcula si está abierto."""
    dias: dict[int, list] = {}
    for h in HorarioSemanal.objects.filter(consultorio=consultorio).order_by("hora_inicio"):
        dias.setdefault(h.dia_semana, []).append(h)
    nombres = dict(HorarioSemanal.DIAS)
    return [
        {
            "dia": nombres[d],
            "dia_semana": d,
            "tramos": [f"{hora_legible(h.hora_inicio)} a {hora_legible(h.hora_fin)}" for h in dias.get(d, [])],
            "rangos": [[f"{h.hora_inicio:%H:%M}", f"{h.hora_fin:%H:%M}"] for h in dias.get(d, [])],
        }
        for d in range(7)
    ]


def perfil_publico(consultorio: Consultorio) -> dict:
    tratamientos = Tratamiento.objects.filter(consultorio=consultorio)
    return {
        "slug": consultorio.slug,
        "nombre": consultorio.nombre,
        "rubro": consultorio.rubro,
        "vocabulario": consultorio.vocabulario,
        "pregunta_servicio": consultorio.tipo["pregunta_servicio"],
        "acepta_reservas": consultorio.acepta_reservas,
        "opciones": opciones_publicas(consultorio),
        "profesionales": [
            profesional_publico(p) for p in consultorio.profesionales.filter(activo=True).prefetch_related("servicios")
        ],
        "doctor": consultorio.doctor_nombre,
        "colegiatura": consultorio.colegiatura,
        "foto": consultorio.foto.url if consultorio.foto else None,
        "presentacion": consultorio.presentacion,
        # Lo que el panel guarda para el sitio: así un sitio propio muestra lo mismo que la landing, sin copiarlo.
        "contenido": {
            clave: consultorio.contenido.get(clave)
            for clave in ("formas_de_pago", "anos_practica", "publico", "referencias", "bloques_confianza")
        },
        "direccion": consultorio.direccion,
        "mapa_url": consultorio.mapa_url,
        "whatsapp": consultorio.whatsapp,
        "horario": horario_publico(consultorio),
        "tratamientos": [tratamiento_publico(t) for t in tratamientos if t.visible],
        "motivos": [tratamiento_publico(t) for t in tratamientos if t.reservable and t.visible],
    }


def cita_publica(cita: Cita) -> dict:
    """Lo que ve el paciente en su enlace. No incluye el celular: quien tenga el enlace no debe obtenerlo."""
    hora_estimada, retraso = None, 0
    hoy = timezone.localdate()
    if cita.estado in (Estado.PROGRAMADA, Estado.EN_CURSO) and cita.inicio.astimezone(LIMA).date() == hoy:
        estimaciones, _ = servicios.estimar_fecha(cita.consultorio, hoy)
        estimacion = estimaciones.get(cita.pk)
        if estimacion:
            hora_estimada, retraso = iso(estimacion.inicio), estimacion.retraso_min

    pendiente = cita.estado == Estado.PENDIENTE
    return {
        "estado": cita.estado,
        "estado_texto": cita.get_estado_display(),
        "inicio": iso(cita.inicio),
        "fin": iso(cita.fin),
        "hora_estimada": hora_estimada,
        "retraso_min": retraso,
        "tratamiento": cita.servicio_nombre or cita.tratamiento.nombre,
        "tratamiento_slug": cita.tratamiento.slug,
        "duracion_min": cita.duracion_acordada_min,
        "profesional": cita.profesional.nombre,
        "paciente": cita.nombre_ingresado or cita.paciente.nombre,
        "consultorio": {
            "nombre": cita.consultorio.nombre,
            "direccion": cita.consultorio.direccion,
            "referencias": cita.consultorio.contenido.get("referencias") or "",
            "mapa_url": cita.consultorio.mapa_url,
            "whatsapp": cita.consultorio.whatsapp,
            "vocabulario": cita.consultorio.vocabulario,
        },
        **precios(cita),
        **llegada(cita),
        "codigo": cita.codigo if pendiente else None,
        "whatsapp_url": servicios.url_verificacion(cita) if pendiente else None,
        "expira_en": iso(cita.expira_en) if pendiente else None,
    }


def reserva_creada(cita: Cita) -> dict:
    pendiente = cita.estado == Estado.PENDIENTE
    return {
        "token": cita.token_gestion,
        "estado": cita.estado,
        "codigo": cita.codigo or None,
        "whatsapp_url": servicios.url_verificacion(cita) if pendiente else None,
        "numero_plataforma": settings.WHATSAPP_NUMERO_PLATAFORMA,
        "expira_en": iso(cita.expira_en),
        "enlace": f"/c/{cita.token_gestion}/",
        "inicio": iso(cita.inicio),
        "tratamiento": cita.servicio_nombre or cita.tratamiento.nombre,
        "duracion_min": cita.duracion_acordada_min,
        "profesional": cita.profesional.nombre,
        "direccion": cita.consultorio.direccion,
        "referencias": cita.consultorio.contenido.get("referencias") or "",
        "mapa_url": cita.consultorio.mapa_url,
        **precios(cita),
        **llegada(cita),
    }


def cita_doctor(cita: Cita, estimacion: Estimacion | None = None) -> dict:
    # Un número sin verificar no puede cambiar el nombre de un paciente que ya existe: la solicitud muestra
    # lo que escribió, y la ficha del paciente sigue intacta.
    nombre = cita.paciente.nombre
    if cita.estado == Estado.POR_APROBAR and cita.nombre_ingresado:
        nombre = cita.nombre_ingresado
    return {
        "id": cita.pk,
        "estado": cita.estado,
        "estado_texto": cita.get_estado_display(),
        "origen": cita.origen,
        "inicio": iso(cita.inicio),
        "fin": iso(cita.fin),
        "inicio_estimado": iso(estimacion.inicio) if estimacion else None,
        "fin_estimado": iso(estimacion.fin) if estimacion else None,
        "retraso_min": estimacion.retraso_min if estimacion else 0,
        "minutos_extra": cita.minutos_extra,
        "recordatorio_enviado_en": iso(cita.recordatorio_enviado_en),
        "asistencia_confirmada": cita.asistencia_confirmada,
        "inicio_real": iso(cita.inicio_real),
        "fin_real": iso(cita.fin_real),
        "llegada_en": iso(cita.llegada_en),
        "profesional": {"id": cita.profesional_id, "nombre": cita.profesional.nombre},
        **precios(cita),
        "tratamiento": {"id": cita.tratamiento_id, "nombre": cita.servicio_nombre or cita.tratamiento.nombre},
        "paciente": {
            "id": cita.paciente_id,
            "nombre": nombre,
            "celular": cita.paciente.celular,
            "inasistencias": cita.paciente.inasistencias,
        },
        "cupon": _cupon_de(cita),
    }


def _cupon_de(cita: Cita) -> dict | None:
    """El cupón que el cliente eligió en la app al reservar: el negocio lo ve antes de confirmar."""
    usado = getattr(cita, "cupon_usado", None)  # sin fila, el acceso inverso lanza un AttributeError
    if usado is None:
        return None
    from clientes.fidelidad import descuento_texto

    return {"codigo": usado.cupon.codigo, "titulo": usado.cupon.titulo, "descuento": descuento_texto(usado.cupon)}


def base_url_consultorio(consultorio: Consultorio, request) -> str:
    """Enlace público de la cita: siempre en el subdominio del consultorio, no en el host de la API."""
    dominio = settings.PLATAFORMA_DOMINIO
    puerto = request.get_port()
    sufijo = f":{puerto}" if settings.DEBUG and puerto not in ("80", "443") else ""
    return f"{request.scheme}://{consultorio.slug}.{dominio}{sufijo}"
