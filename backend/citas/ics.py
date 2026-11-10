"""Archivo de calendario con alarmas 24 h y 2 h antes (RF-12). RFC 5545, sin dependencias."""
from __future__ import annotations

from datetime import datetime, timezone


def _texto(valor: str) -> str:
    return (
        valor.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\r\n", "\\n").replace("\n", "\\n")
    )


def _plegar(linea: str) -> str:
    """Pliega a 75 octetos por línea sin partir caracteres multibyte."""
    partes, actual, tamano = [], "", 0
    for caracter in linea:
        octetos = len(caracter.encode("utf-8"))
        if tamano + octetos > 75:
            partes.append(actual)
            actual, tamano = " ", 1
        actual += caracter
        tamano += octetos
    partes.append(actual)
    return "\r\n".join(partes)


def _utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _alarma(disparo: str, descripcion: str) -> list[str]:
    return ["BEGIN:VALARM", f"TRIGGER:{disparo}", "ACTION:DISPLAY", f"DESCRIPTION:{_texto(descripcion)}", "END:VALARM"]


def generar_ics(
    *,
    uid: str,
    inicio: datetime,
    fin: datetime,
    resumen: str,
    ubicacion: str,
    descripcion: str,
    secuencia: int = 0,
    ahora: datetime,
) -> str:
    lineas = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//RyCitas//Reservas//ES",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "BEGIN:VEVENT",
        f"UID:{uid}",
        f"SEQUENCE:{secuencia}",
        f"DTSTAMP:{_utc(ahora)}",
        f"DTSTART:{_utc(inicio)}",
        f"DTEND:{_utc(fin)}",
        f"SUMMARY:{_texto(resumen)}",
        f"LOCATION:{_texto(ubicacion)}",
        f"DESCRIPTION:{_texto(descripcion)}",
        *_alarma("-PT24H", f"Mañana: {resumen}"),
        *_alarma("-PT2H", f"En 2 horas: {resumen}"),
        "END:VEVENT",
        "END:VCALENDAR",
    ]
    return "\r\n".join(_plegar(linea) for linea in lineas) + "\r\n"
