"""Gamificación del cliente: logros, racha y nivel global (los puntos se quitaron: no servían para nada y confundían). Se calcula al vuelo con sus citas y sellos (sin
tablas nuevas), en todos los lugares donde reservó con su WhatsApp.

Gamificación sin culpa:
- La racha no castiga: un mes sin visita la deja «en pausa», no la borra.
- Las recompensas reales son los sellos y cupones de cada negocio; logros y nivel solo muestran el avance.
"""
from __future__ import annotations

from datetime import date

from django.utils import timezone

from citas.models import Cita, Estado
from clientes.models import Cliente, Sello

# (visitas mínimas, nombre del nivel)
NIVELES = [(0, "Nueva"), (3, "Habitual"), (8, "Fiel"), (15, "VIP"), (30, "Leyenda")]


def _nivel(visitas: int) -> dict:
    actual = [n for n in NIVELES if visitas >= n[0]][-1]
    siguiente = next((n for n in NIVELES if n[0] > visitas), None)
    return {
        "nombre": actual[1],
        "siguiente": siguiente[1] if siguiente else None,
        "faltan": siguiente[0] - visitas if siguiente else 0,
        # Avance dentro del nivel actual (0 a 1): llena la barra.
        "progreso": 1.0 if siguiente is None else round((visitas - actual[0]) / (siguiente[0] - actual[0]), 2),
    }


def _mes(d: date) -> int:
    return d.year * 12 + d.month - 1


def _racha(meses_con_visita: set[int], hoy: date) -> tuple[int, bool]:
    """Meses seguidos con alguna visita, contando hacia atrás desde la última. Activa si es de este mes o el anterior."""
    if not meses_con_visita:
        return 0, False
    ultimo = max(meses_con_visita)
    racha = 0
    while ultimo - racha in meses_con_visita:
        racha += 1
    return racha, _mes(hoy) - ultimo <= 1


def resumen(cliente: Cliente, confiable: bool) -> dict:
    citas = Cita.objects.none()
    if confiable:
        citas = Cita.objects.filter(paciente__celular=cliente.celular, consultorio__activo=True)
    terminadas = list(citas.filter(estado=Estado.TERMINADA).values("inicio", "tratamiento__nombre", "servicio_nombre"))
    visitas = len(terminadas)
    servicios = {t["servicio_nombre"] or t["tratamiento__nombre"] for t in terminadas}
    ultimas = list(
        citas.filter(estado__in=[Estado.TERMINADA, Estado.NO_ASISTIO]).order_by("-inicio").values_list("estado", flat=True)[:5]
    )
    seguidas = 0
    for estado in ultimas:
        if estado != Estado.TERMINADA:
            break
        seguidas += 1
    trajo = cliente.referidos.filter(referido_premiado_en__isnull=False).count() if confiable else 0
    sellos = Sello.objects.filter(celular=cliente.celular).count() if confiable else 0
    hoy = timezone.localdate()
    meses = {_mes(timezone.localtime(t["inicio"]).date()) for t in terminadas}
    racha, activa = _racha(meses, hoy)

    def logro(clave, titulo, como, valor, meta, icono):
        return {
            "clave": clave,
            "titulo": titulo,
            "como": como,
            "progreso": min(valor, meta),
            "meta": meta,
            "logrado": valor >= meta,
            "icono": icono,
        }

    return {
        "logros": [
            logro("primera", "Primera cita", "Completa tu primera visita.", visitas, 1, "estrella"),
            logro("fiel", "Cliente fiel", "Completa 5 visitas.", visitas, 5, "corazon"),
            logro("puntual", "Siempre presente", "Asiste a 5 citas seguidas.", seguidas, 5, "reloj"),
            logro("explorador", "Exploradora", "Prueba 3 servicios distintos.", len(servicios), 3, "brujula"),
            logro("embajador", "Embajadora", "Invita a alguien que reserve y asista.", trajo, 1, "regalo"),
            logro("racha", "Racha de 3 meses", "Visita algún lugar 3 meses seguidos.", racha, 3, "fuego"),
        ],
        "visitas": visitas,
        "sellos": sellos,
        "racha": racha,
        "racha_activa": activa,
        "nivel": _nivel(visitas),
    }
