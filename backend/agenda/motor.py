"""Motor de agenda: horario - bloqueos - citas = horas libres.

Es una función pura: no toca la base de datos ni el reloj. Todo llega por parámetros, por eso se
puede probar exhaustivamente. Es la pieza que no puede fallar (RF-06).
"""
from __future__ import annotations

from bisect import bisect_right
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Iterable
from zoneinfo import ZoneInfo

LIMA = ZoneInfo("America/Lima")


@dataclass(frozen=True)
class Tramo:
    """Un tramo de atención. dia_semana: 0 = lunes ... 6 = domingo."""

    dia_semana: int
    inicio: time
    fin: time


@dataclass(frozen=True)
class Intervalo:
    """Tiempo ocupado [inicio, fin). Las citas incluyen su margen en `fin`."""

    inicio: datetime
    fin: datetime


@dataclass(frozen=True)
class ParametrosReserva:
    duracion_min: int
    margen_min: int = 0
    anticipacion_min_horas: float = 2
    dias_maximos: int = 30
    paso_min: int = 15


def tramos_del_dia(tramos: Iterable[Tramo], dia_semana: int) -> list[tuple[time, time]]:
    """Tramos de un día ordenados y unidos si se tocan: 9-13 y 13-18 forman un solo bloque 9-18."""
    ordenados = sorted((t.inicio, t.fin) for t in tramos if t.dia_semana == dia_semana and t.inicio < t.fin)
    unidos: list[tuple[time, time]] = []
    for inicio, fin in ordenados:
        if unidos and inicio <= unidos[-1][1]:
            unidos[-1] = (unidos[-1][0], max(unidos[-1][1], fin))
        else:
            unidos.append((inicio, fin))
    return unidos


def _unir_ocupados(ocupados: Iterable[Intervalo]) -> tuple[list[float], list[float]]:
    """Intervalos sin superposición, ordenados y en segundos.

    Comparar números es mucho más barato que comparar fechas con zona horaria, y este cálculo se repite
    para cada hora de cada día en cada consulta de disponibilidad (RNF-03).
    """
    inicios: list[float] = []
    fines: list[float] = []
    for inicio, fin in sorted((o.inicio.timestamp(), o.fin.timestamp()) for o in ocupados):
        if fines and inicio <= fines[-1]:
            fines[-1] = max(fines[-1], fin)
        else:
            inicios.append(inicio)
            fines.append(fin)
    return inicios, fines


def _horas_del_dia(
    fecha: date,
    tramos: list[tuple[time, time]],
    inicios: list[float],
    fines: list[float],
    params: ParametrosReserva,
    limite: float,
    tz: ZoneInfo,
) -> list[datetime]:
    duracion = params.duracion_min * 60
    bloque = duracion + params.margen_min * 60
    paso = params.paso_min * 60
    libres: list[datetime] = []
    for t_inicio, t_fin in tramos:
        apertura = datetime.combine(fecha, t_inicio, tz)
        base = apertura.timestamp()
        cierre = datetime.combine(fecha, t_fin, tz).timestamp()
        hora = base
        # Como las horas avanzan, el primer intervalo que aún no termina solo se busca una vez.
        i = bisect_right(fines, hora)
        while hora + duracion <= cierre:
            while i < len(fines) and fines[i] <= hora:
                i += 1
            libre = i == len(inicios) or inicios[i] >= hora + bloque
            if hora >= limite and libre:
                libres.append(apertura + timedelta(seconds=hora - base))
            hora += paso
    return libres


def horas_libres(
    fecha: date,
    tramos: Iterable[Tramo],
    ocupados: Iterable[Intervalo],
    params: ParametrosReserva,
    ahora: datetime,
    tz: ZoneInfo = LIMA,
) -> list[datetime]:
    """Horas de inicio donde la cita cabe completa en `fecha`.

    Una hora se ofrece solo si:
    - la atención (duración) termina dentro del mismo tramo; el margen puede pasar del cierre;
    - la atención más el margen no se cruza con otra cita ni con un bloqueo;
    - respeta la anticipación mínima desde `ahora`.
    """
    if params.duracion_min <= 0 or params.paso_min <= 0:
        return []
    inicios, fines = _unir_ocupados(ocupados)
    limite = (ahora + timedelta(hours=params.anticipacion_min_horas)).timestamp()
    return _horas_del_dia(fecha, tramos_del_dia(tramos, fecha.weekday()), inicios, fines, params, limite, tz)


def disponibilidad(
    desde: date,
    dias: int,
    tramos: Iterable[Tramo],
    ocupados: Iterable[Intervalo],
    params: ParametrosReserva,
    ahora: datetime,
    tz: ZoneInfo = LIMA,
) -> dict[date, list[datetime]]:
    """Días con espacio dentro de la ventana permitida: nunca antes de hoy ni más allá de `dias_maximos`."""
    if params.duracion_min <= 0 or params.paso_min <= 0:
        return {}
    tramos = list(tramos)
    tramos_por_dia = {d: tramos_del_dia(tramos, d) for d in range(7)}
    inicios, fines = _unir_ocupados(ocupados)
    limite = (ahora + timedelta(hours=params.anticipacion_min_horas)).timestamp()
    hoy = ahora.astimezone(tz).date()
    inicio = max(desde, hoy)
    ultimo_permitido = hoy + timedelta(days=params.dias_maximos - 1)
    ultimo = min(inicio + timedelta(days=dias - 1), ultimo_permitido)

    resultado: dict[date, list[datetime]] = {}
    fecha = inicio
    while fecha <= ultimo:
        libres = _horas_del_dia(fecha, tramos_por_dia[fecha.weekday()], inicios, fines, params, limite, tz)
        if libres:
            resultado[fecha] = libres
        fecha += timedelta(days=1)
    return resultado


def huecos_del_dia(
    fecha: date,
    tramos: Iterable[Tramo],
    ocupados: Iterable[Intervalo],
    minimo_min: int = 15,
    tz: ZoneInfo = LIMA,
) -> list[Intervalo]:
    """Tiempo libre dentro del horario de `fecha`; alimenta la pantalla Hoy (RF-21)."""
    huecos: list[Intervalo] = []
    ordenados = sorted(ocupados, key=lambda o: o.inicio)
    minimo = timedelta(minutes=minimo_min)
    for t_inicio, t_fin in tramos_del_dia(tramos, fecha.weekday()):
        cursor = datetime.combine(fecha, t_inicio, tz)
        cierre = datetime.combine(fecha, t_fin, tz)
        for o in ordenados:
            if o.fin <= cursor or o.inicio >= cierre:
                continue
            if o.inicio - cursor >= minimo:
                huecos.append(Intervalo(cursor, o.inicio))
            cursor = max(cursor, o.fin)
        if cierre - cursor >= minimo:
            huecos.append(Intervalo(cursor, cierre))
    return huecos
