"""Lo que hace el panel con cada negocio. Las vistas solo validan formularios y llaman aquí."""
from __future__ import annotations

import csv
import io
import secrets
from datetime import time
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from agenda.models import HorarioSemanal, Tratamiento
from citas.models import Cita, Paciente
from consultorios.models import Consultorio, Profesional, SesionRenovacion, Usuario
from consultorios.rubros import rubro as datos_rubro
from panel.models import EventoPanel
from sitio.cache import purgar_sitio


def registrar(autor: Usuario | None, consultorio: Consultorio | None, accion: str, detalle: str = "") -> None:
    EventoPanel.objects.create(usuario=autor, consultorio=consultorio, accion=accion, detalle=detalle[:300])


def servicios_sugeridos(clave: str) -> list[dict]:
    return [
        {
            "nombre": nombre,
            "motivo": motivo,
            "duracion_min": duracion,
            "margen_min": margen,
            "precio": precio,
            "indicaciones": indicaciones,
        }
        for nombre, motivo, duracion, margen, precio, indicaciones in datos_rubro(clave)["servicios"]
    ]


def horario_sugerido(clave: str) -> list[tuple[int, time, time]]:
    return list(datos_rubro(clave)["horario"])


def contrasena_nueva() -> str:
    """Fácil de dictar por teléfono y difícil de adivinar: 12 caracteres sin letras que se confunden."""
    alfabeto = "abcdefghjkmnpqrstuvwxyz23456789"
    return "-".join("".join(secrets.choice(alfabeto) for _ in range(4)) for _ in range(3))


@transaction.atomic
def crear_negocio(
    *,
    autor: Usuario,
    rubro: str,
    nombre: str,
    slug: str,
    whatsapp: str,
    direccion: str,
    mapa_url: str = "",
    profesionales: list[str],
    servicios: list[dict],
    horario: list[tuple[int, time, time]],
    opciones: dict,
) -> Consultorio:
    """Nace como borrador (sin publicar): el panel muestra la vista previa antes de publicarlo."""
    nombres = [p.strip() for p in profesionales if p.strip()] or [nombre]
    consultorio = Consultorio.objects.create(
        rubro=rubro,
        nombre=nombre,
        slug=slug,
        whatsapp=whatsapp,
        direccion=direccion,
        mapa_url=mapa_url,
        doctor_nombre=nombres[0],
        opciones=opciones,
        publicado=False,
    )
    # La señal ya creó al profesional principal con el primer nombre.
    for orden, extra in enumerate(nombres[1:], start=1):
        Profesional.objects.create(consultorio=consultorio, nombre=extra, orden=orden)
    for orden, s in enumerate(servicios):
        Tratamiento.objects.create(
            consultorio=consultorio,
            nombre=s["nombre"],
            motivo_paciente=s.get("motivo", ""),
            duracion_min=s["duracion_min"],
            margen_min=s.get("margen_min", 0),
            precio_desde=Decimal(str(s["precio"])) if s.get("precio") not in (None, "") else None,
            indicaciones=s.get("indicaciones", ""),
            orden=orden,
        )
    HorarioSemanal.objects.bulk_create(
        HorarioSemanal(consultorio=consultorio, dia_semana=d, hora_inicio=i, hora_fin=f) for d, i, f in horario
    )
    registrar(autor, consultorio, "crear", f"{datos_rubro(rubro)['nombre']} · {len(nombres)} profesional(es)")
    return consultorio


def crear_cuenta(
    autor: Usuario, consultorio: Consultorio, correo: str, nombre: str = "", profesional: Profesional | None = None
) -> tuple[Usuario, str]:
    clave = contrasena_nueva()
    usuario = Usuario.objects.create_user(
        correo.strip().lower(), clave, consultorio=consultorio, nombre=nombre, profesional=profesional
    )
    registrar(autor, consultorio, "cuenta_creada", usuario.correo)
    return usuario, clave


def cerrar_sesiones(usuario: Usuario) -> int:
    """La app pierde la sesión en todos los equipos en cuanto vence su token de acceso (minutos)."""
    return SesionRenovacion.objects.filter(usuario=usuario, revocado=False).update(revocado=True)


def restablecer_contrasena(autor: Usuario, usuario: Usuario) -> str:
    clave = contrasena_nueva()
    usuario.set_password(clave)
    usuario.intentos_fallidos = 0
    usuario.bloqueado_hasta = None
    usuario.save()
    cerrar_sesiones(usuario)
    registrar(autor, usuario.consultorio, "contrasena", usuario.correo)
    return clave


def cambiar_activo(autor: Usuario, usuario: Usuario, activo: bool) -> None:
    usuario.activo = activo
    usuario.save(update_fields=["activo"])
    if not activo:
        cerrar_sesiones(usuario)
    registrar(autor, usuario.consultorio, "cuenta_activada" if activo else "cuenta_desactivada", usuario.correo)


def publicar(autor: Usuario, consultorio: Consultorio, publicado: bool) -> None:
    consultorio.publicado = publicado
    consultorio.save(update_fields=["publicado"])
    purgar_sitio(consultorio.slug)
    registrar(autor, consultorio, "publicar" if publicado else "despublicar")


def suspender(autor: Usuario, consultorio: Consultorio, suspendido: bool, motivo: str = "") -> None:
    """Nunca cancela citas: solo deja de aceptar reservas en línea. La app sigue funcionando."""
    consultorio.suspendido = suspendido
    consultorio.save(update_fields=["suspendido"])
    purgar_sitio(consultorio.slug)
    registrar(autor, consultorio, "suspender" if suspendido else "reactivar", motivo)


def estado_de(consultorio: Consultorio) -> str:
    if consultorio.suspendido:
        return "suspendido"
    if not consultorio.publicado:
        return "borrador"
    return "publicado"


def dias_para_vencer(consultorio: Consultorio) -> int | None:
    if consultorio.servicio_hasta is None:
        return None
    return (consultorio.servicio_hasta - timezone.localdate()).days


def exportar_citas(consultorio: Consultorio) -> str:
    """CSV para entregar al negocio si deja el servicio (DEC-005): nunca se borran sus datos por vencimiento."""
    salida = io.StringIO()
    escritor = csv.writer(salida)
    escritor.writerow(
        ["inicio", "fin", "estado", "servicio", "profesional", "cliente", "celular", "precio_referencia",
         "precio_acordado", "origen", "creada"]
    )
    citas = Cita.objects.filter(consultorio=consultorio).select_related("paciente", "profesional").order_by("inicio")
    for c in citas:
        escritor.writerow([
            timezone.localtime(c.inicio).isoformat(timespec="minutes"),
            timezone.localtime(c.fin).isoformat(timespec="minutes"),
            c.get_estado_display(),
            c.servicio_nombre,
            c.profesional.nombre,
            c.paciente.nombre,
            c.paciente.celular,
            _soles(c.precio_referencia),
            _soles(c.precio_acordado),
            c.get_origen_display(),
            timezone.localtime(c.creado_en).isoformat(timespec="minutes"),
        ])
    return salida.getvalue()


def exportar_clientes(consultorio: Consultorio) -> str:
    salida = io.StringIO()
    escritor = csv.writer(salida)
    escritor.writerow(["nombre", "celular", "citas", "inasistencias", "bloqueado"])
    for p in Paciente.objects.filter(consultorio=consultorio).order_by("nombre"):
        escritor.writerow([p.nombre, p.celular, p.citas.count(), p.inasistencias, "sí" if p.bloqueado else "no"])
    return salida.getvalue()


def _soles(centimos: int | None) -> str:
    return "" if centimos is None else f"{centimos / 100:.2f}"
