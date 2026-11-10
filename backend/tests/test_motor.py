"""Motor de agenda: función pura, sin base de datos (RF-06)."""
import random
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from agenda.motor import Intervalo, ParametrosReserva, Tramo, disponibilidad, horas_libres, huecos_del_dia, tramos_del_dia

LIMA = ZoneInfo("America/Lima")
LUNES = date(2026, 11, 9)
DOMINGO_ANTES = datetime(2026, 11, 8, 12, 0, tzinfo=LIMA)
MANANA = [Tramo(0, time(9), time(13))]


def en(h, m=0, fecha=LUNES):
    return datetime.combine(fecha, time(h, m), LIMA)


def horas(lista):
    return [d.strftime("%H:%M") for d in lista]


def libres(tramos=MANANA, ocupados=(), ahora=DOMINGO_ANTES, fecha=LUNES, **p):
    p.setdefault("duracion_min", 30)
    return horas_libres(fecha, tramos, ocupados, ParametrosReserva(**p), ahora)


def test_ofrece_cada_paso_mientras_la_cita_cabe_completa():
    assert horas(libres(paso_min=30)) == ["09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "12:00", "12:30"]


def test_no_ofrece_una_hora_donde_la_cita_no_termina_antes_del_cierre():
    assert horas(libres(duracion_min=60, paso_min=15))[-1] == "12:00"


def test_el_margen_puede_pasar_del_cierre_pero_la_atencion_no():
    assert "12:30" in horas(libres(duracion_min=30, margen_min=30, paso_min=30))


def test_cita_mas_larga_que_el_tramo_no_tiene_horas():
    assert libres(duracion_min=300) == []


def test_dia_sin_horario_no_ofrece_nada():
    assert libres(fecha=date(2026, 11, 10)) == []


def test_nunca_se_cruza_con_una_cita():
    resultado = horas(libres(ocupados=[Intervalo(en(10), en(10, 45))], paso_min=15))
    assert "09:30" in resultado
    assert "09:45" not in resultado  # terminaría 10:15, dentro de la cita
    assert "10:00" not in resultado and "10:30" not in resultado
    assert "10:45" in resultado  # exactamente al terminar: [inicio, fin) no se cruza


def test_cita_que_termina_justo_cuando_empieza_la_siguiente_es_valida():
    assert "09:30" in horas(libres(ocupados=[Intervalo(en(10), en(10, 30))], paso_min=30))


def test_el_margen_propio_tampoco_se_cruza_con_la_siguiente():
    resultado = horas(libres(ocupados=[Intervalo(en(10), en(11))], margen_min=10, paso_min=15))
    assert "09:15" in resultado  # 9:15 + 30 + 10 = 9:55
    assert "09:30" not in resultado  # 9:30 + 30 + 10 = 10:10, invade la siguiente


def test_nunca_se_cruza_con_un_bloqueo_de_varios_dias():
    bloqueo = Intervalo(en(0, fecha=date(2026, 11, 8)), en(0, fecha=date(2026, 11, 11)))
    assert libres(ocupados=[bloqueo]) == []


def test_respeta_la_anticipacion_minima_de_2_horas():
    resultado = horas(libres(ahora=en(9, 10), paso_min=15, anticipacion_min_horas=2))
    assert resultado[0] == "11:15"


def test_la_anticipacion_exacta_se_acepta():
    assert horas(libres(ahora=en(9), paso_min=60, anticipacion_min_horas=2))[0] == "11:00"


def test_doctor_sin_anticipacion():
    assert horas(libres(ahora=en(9), paso_min=60, anticipacion_min_horas=0))[0] == "09:00"


def test_varios_tramos_respetan_el_descanso():
    tramos = [Tramo(0, time(9), time(10)), Tramo(0, time(15), time(16))]
    assert horas(libres(tramos=tramos, paso_min=30)) == ["09:00", "09:30", "15:00", "15:30"]


def test_una_cita_no_atraviesa_el_descanso():
    tramos = [Tramo(0, time(9), time(10)), Tramo(0, time(15), time(16))]
    assert "09:30" not in horas(libres(tramos=tramos, duracion_min=60, paso_min=30))


def test_tramos_contiguos_se_unen():
    assert tramos_del_dia([Tramo(0, time(13), time(18)), Tramo(0, time(9), time(13))], 0) == [(time(9), time(18))]
    tramos = [Tramo(0, time(9), time(10)), Tramo(0, time(10), time(11))]
    assert "09:30" in horas(libres(tramos=tramos, duracion_min=60, paso_min=30))


def test_tramos_superpuestos_no_duplican_horas():
    tramos = [Tramo(0, time(9), time(11)), Tramo(0, time(10), time(12))]
    resultado = libres(tramos=tramos, paso_min=30)
    assert len(resultado) == len(set(resultado))


def test_tramo_invertido_se_ignora():
    assert tramos_del_dia([Tramo(0, time(13), time(9))], 0) == []


def test_duracion_o_paso_invalidos_no_rompen_el_bucle():
    assert libres(duracion_min=0) == []
    assert libres(paso_min=0) == []


def test_ocupado_guardado_en_utc_se_compara_bien():
    utc = ZoneInfo("UTC")
    ocupado = Intervalo(en(10).astimezone(utc), en(11).astimezone(utc))
    assert "10:00" not in horas(libres(ocupados=[ocupado], paso_min=30))


def test_todas_las_horas_salen_en_hora_de_lima():
    assert all(h.utcoffset() == timedelta(hours=-5) for h in libres())


def test_ahora_en_otra_zona_horaria_da_el_mismo_resultado():
    ahora_utc = en(9).astimezone(ZoneInfo("UTC"))
    assert libres(ahora=ahora_utc, paso_min=60) == libres(ahora=en(9), paso_min=60)


def _dias(**kw):
    kw.setdefault("desde", LUNES)
    kw.setdefault("dias", 30)
    kw.setdefault("ocupados", [])
    kw.setdefault("ahora", DOMINGO_ANTES)
    tramos = kw.pop("tramos", [Tramo(d, time(9), time(13)) for d in range(7)])
    params = ParametrosReserva(duracion_min=30, dias_maximos=kw.pop("dias_maximos", 30))
    return disponibilidad(kw["desde"], kw["dias"], tramos, kw["ocupados"], params, kw["ahora"])


def test_ventana_de_30_dias_contando_hoy():
    resultado = _dias(desde=date(2026, 11, 8))
    assert max(resultado) == date(2026, 11, 8) + timedelta(days=29)


def test_no_pasa_de_dias_maximos_aunque_se_pidan_mas():
    resultado = _dias(dias=90)
    assert max(resultado) == date(2026, 11, 8) + timedelta(days=29)


def test_desde_en_el_pasado_empieza_hoy():
    temprano = datetime(2026, 11, 8, 6, 0, tzinfo=LIMA)  # el domingo aún tiene horas libres
    assert min(_dias(desde=date(2020, 1, 1), ahora=temprano)) == date(2026, 11, 8)


def test_dias_sin_espacio_no_aparecen():
    lleno = Intervalo(en(0), en(0, fecha=date(2026, 11, 10)))
    assert LUNES not in _dias(ocupados=[lleno])


def test_solo_dias_con_horario():
    resultado = _dias(tramos=[Tramo(2, time(9), time(10))])
    assert all(f.weekday() == 2 for f in resultado)


def test_huecos_entre_citas():
    huecos = huecos_del_dia(LUNES, MANANA, [Intervalo(en(10), en(11)), Intervalo(en(11), en(12))])
    assert [(h.inicio.hour, h.fin.hour) for h in huecos] == [(9, 10), (12, 13)]


def test_hueco_menor_al_minimo_no_cuenta():
    huecos = huecos_del_dia(LUNES, MANANA, [Intervalo(en(9, 10), en(13))], minimo_min=15)
    assert huecos == []


def test_dia_sin_citas_es_un_solo_hueco():
    assert len(huecos_del_dia(LUNES, MANANA, [])) == 1


def test_ocupado_fuera_del_tramo_no_afecta_los_huecos():
    assert len(huecos_del_dia(LUNES, MANANA, [Intervalo(en(15), en(16))])) == 1


def _referencia(fecha, tramos, ocupados, p, ahora):
    """Definición literal de la regla, sin optimizar: contra esto se compara el motor."""
    limite = ahora + timedelta(hours=p.anticipacion_min_horas)
    duracion, bloque = timedelta(minutes=p.duracion_min), timedelta(minutes=p.duracion_min + p.margen_min)
    libres = []
    for t_inicio, t_fin in tramos_del_dia(tramos, fecha.weekday()):
        hora, cierre = datetime.combine(fecha, t_inicio, LIMA), datetime.combine(fecha, t_fin, LIMA)
        while hora + duracion <= cierre:
            cruza = any(hora < o.fin and o.inicio < hora + bloque for o in ocupados)
            if hora >= limite and not cruza:
                libres.append(hora)
            hora += timedelta(minutes=p.paso_min)
    return libres


def test_el_motor_coincide_con_la_definicion_en_miles_de_casos_aleatorios():
    azar = random.Random(20261109)
    for _ in range(3000):
        tramos = []
        for _ in range(azar.randint(0, 3)):
            a, b = sorted(azar.sample(range(7 * 4, 21 * 4), 2))
            tramos.append(Tramo(0, time(a // 4, a % 4 * 15), time(b // 4, b % 4 * 15)))
        ocupados = []
        for _ in range(azar.randint(0, 8)):
            inicio = en(0) + timedelta(minutes=azar.randrange(5 * 60, 23 * 60, 5))
            ocupados.append(Intervalo(inicio, inicio + timedelta(minutes=azar.randrange(5, 300, 5))))
        params = ParametrosReserva(
            duracion_min=azar.choice([15, 20, 30, 45, 60, 90]),
            margen_min=azar.choice([0, 5, 10, 30]),
            anticipacion_min_horas=azar.choice([0, 2]),
            paso_min=azar.choice([5, 15, 30]),
        )
        ahora = en(0) + timedelta(minutes=azar.randrange(0, 24 * 60, 7))
        caso = (LUNES, tramos, ocupados, params, ahora)
        assert horas_libres(*caso) == _referencia(*caso), caso
        assert disponibilidad(LUNES, 1, tramos, ocupados, params, ahora).get(LUNES, []) == _referencia(*caso), caso


def test_ninguna_hora_ofrecida_se_cruza_jamas():
    azar = random.Random(7)
    params = ParametrosReserva(duracion_min=30, margen_min=10, anticipacion_min_horas=0)
    for _ in range(500):
        ocupados = []
        for _ in range(azar.randint(1, 10)):
            inicio = en(9) + timedelta(minutes=azar.randrange(0, 240, 5))
            ocupados.append(Intervalo(inicio, inicio + timedelta(minutes=azar.randrange(5, 90, 5))))
        for hora in horas_libres(LUNES, MANANA, ocupados, params, en(0)):
            fin = hora + timedelta(minutes=40)
            assert all(fin <= o.inicio or hora >= o.fin for o in ocupados)
