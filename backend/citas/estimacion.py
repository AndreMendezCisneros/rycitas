"""Hora estimada de cada cita del día (RF-21, RF-22, RF-14). Función pura, igual que el motor."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class CitaPlan:
    id: int
    estado: str
    inicio: datetime
    fin: datetime
    fin_ocupado: datetime
    minutos_extra: int = 0
    inicio_real: datetime | None = None
    fin_real: datetime | None = None
    demora_min: int = 0


@dataclass(frozen=True)
class Estimacion:
    inicio: datetime
    fin: datetime
    retraso_min: int


def estimar_dia(citas: list[CitaPlan], ahora: datetime | None) -> tuple[dict[int, Estimacion], int]:
    """Devuelve la estimación por cita y el retraso acumulado actual del día.

    - `ahora=None` para días pasados: no hay "siguiente paciente" que empujar.
    - Nadie se adelanta: una cita nunca se estima antes de su hora programada.
    - Solo cuentan programada, en_curso y terminada; pre-reservas, por aprobar y salidas no ocupan al doctor.
    """
    estimaciones: dict[int, Estimacion] = {}
    cursor: datetime | None = None
    retraso_actual = 0

    ordenadas = sorted(citas, key=lambda x: x.inicio)
    for c in ordenadas:
        duracion = c.fin - c.inicio
        margen = c.fin_ocupado - c.fin
        extra = timedelta(minutes=c.minutos_extra)

        if c.estado == "terminada":
            inicio = c.inicio_real or c.inicio
            fin = c.fin_real or (inicio + duracion)
            cursor = max(cursor, fin + margen) if cursor else fin + margen
            retraso_actual = 0
        elif c.estado == "en_curso":
            inicio = c.inicio_real or c.inicio
            fin = inicio + duracion + extra
            if ahora and ahora > fin:  # se pasó de lo previsto: como mínimo termina ahora
                fin = ahora
            cursor = fin + margen
            retraso_actual = max(0, int((fin - c.fin).total_seconds() // 60))
        elif c.estado == "programada":
            inicio = c.inicio + timedelta(minutes=c.demora_min)
            if cursor and cursor > inicio:
                inicio = cursor
            if ahora and ahora > inicio:
                inicio = ahora
            fin = inicio + duracion + extra
            cursor = fin + margen
        else:
            continue

        retraso = max(0, int((inicio - c.inicio).total_seconds() // 60))
        estimaciones[c.id] = Estimacion(inicio, fin, retraso)

    primera_por_atender = next((c for c in ordenadas if c.estado == "programada"), None)
    if primera_por_atender:
        retraso_actual = estimaciones[primera_por_atender.id].retraso_min
    return estimaciones, retraso_actual
