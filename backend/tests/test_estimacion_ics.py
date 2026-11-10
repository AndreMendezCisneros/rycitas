from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from citas.estimacion import CitaPlan, estimar_dia
from citas.ics import generar_ics

LIMA = ZoneInfo("America/Lima")


def en(h, m=0):
    return datetime(2026, 11, 9, h, m, tzinfo=LIMA)


def cita(id, h, m=0, dur=30, margen=0, estado="programada", **extra):
    inicio = en(h, m)
    fin = inicio + timedelta(minutes=dur)
    return CitaPlan(id, estado, inicio, fin, fin + timedelta(minutes=margen), **extra)


def test_sin_retraso_cada_cita_conserva_su_hora():
    est, retraso = estimar_dia([cita(1, 9), cita(2, 10)], en(8))
    assert est[1].inicio == en(9) and est[2].inicio == en(10)
    assert retraso == 0


def test_cita_en_curso_con_extension_empuja_a_la_siguiente():
    en_curso = cita(1, 9, estado="en_curso", inicio_real=en(9), minutos_extra=20)
    est, retraso = estimar_dia([en_curso, cita(2, 9, 30)], en(9, 5))
    assert est[1].fin == en(9, 50)
    assert est[2].inicio == en(9, 50)
    assert est[2].retraso_min == 20
    assert retraso == 20


def test_el_retraso_se_propaga_en_cadena():
    en_curso = cita(1, 9, estado="en_curso", inicio_real=en(9, 15))
    est, _ = estimar_dia([en_curso, cita(2, 9, 30), cita(3, 10)], en(9, 20))
    assert est[2].inicio == en(9, 45)
    assert est[3].inicio == en(10, 15)


def test_un_hueco_absorbe_el_retraso():
    en_curso = cita(1, 9, estado="en_curso", inicio_real=en(9, 10))
    est, _ = estimar_dia([en_curso, cita(2, 11)], en(9, 15))
    assert est[2].inicio == en(11)
    assert est[2].retraso_min == 0


def test_terminar_antes_no_adelanta_a_nadie():
    terminada = cita(1, 9, estado="terminada", inicio_real=en(9), fin_real=en(9, 10))
    est, retraso = estimar_dia([terminada, cita(2, 9, 30)], en(9, 11))
    assert est[2].inicio == en(9, 30)
    assert retraso == 0


def test_terminar_tarde_empuja_con_la_duracion_real():
    terminada = cita(1, 9, estado="terminada", inicio_real=en(9), fin_real=en(9, 50))
    est, retraso = estimar_dia([terminada, cita(2, 9, 30)], en(9, 50))
    assert est[2].inicio == en(9, 50)
    assert retraso == 20


def test_se_paso_del_tiempo_previsto_sin_tocar_extender():
    en_curso = cita(1, 9, estado="en_curso", inicio_real=en(9))
    est, _ = estimar_dia([en_curso, cita(2, 9, 30)], en(10))
    assert est[1].fin == en(10)
    assert est[2].inicio == en(10)


def test_si_nadie_inicia_la_siguiente_se_estima_desde_ahora():
    est, retraso = estimar_dia([cita(1, 9)], en(9, 25))
    assert est[1].inicio == en(9, 25)
    assert retraso == 25


def test_el_margen_cuenta_para_la_siguiente():
    en_curso = cita(1, 9, margen=10, estado="en_curso", inicio_real=en(9, 5))
    est, _ = estimar_dia([en_curso, cita(2, 9, 40)], en(9, 6))
    assert est[2].inicio == en(9, 45)


def test_citas_canceladas_o_ausentes_no_empujan():
    est, _ = estimar_dia([cita(1, 9, estado="cancelada"), cita(2, 9, 15, estado="no_asistio"), cita(3, 10)], en(8))
    assert set(est) == {3}
    assert est[3].inicio == en(10)


def test_dia_pasado_sin_ahora_no_inventa_retrasos():
    est, retraso = estimar_dia([cita(1, 9)], None)
    assert est[1].inicio == en(9)
    assert retraso == 0


def test_solo_en_curso_reporta_su_propio_retraso():
    en_curso = cita(1, 9, estado="en_curso", inicio_real=en(9, 10))
    _, retraso = estimar_dia([en_curso], en(9, 15))
    assert retraso == 10


def _ics(**extra):
    datos = dict(
        uid="cita-1@denticita.test",
        inicio=en(9),
        fin=en(9, 30),
        resumen="Cita en Sonrisa, Wari; prueba",
        ubicacion="Jr. Asamblea 123, Ayacucho",
        descripcion="Limpieza\nVer: https://sonrisa.denticita.test/cita/" + "x" * 80 + "/",
        ahora=en(8),
    )
    return generar_ics(**{**datos, **extra})


def test_ics_tiene_las_dos_alarmas():
    contenido = _ics()
    assert contenido.count("BEGIN:VALARM") == 2
    assert "TRIGGER:-PT24H" in contenido and "TRIGGER:-PT2H" in contenido


def test_ics_guarda_la_hora_en_utc():
    assert "DTSTART:20261109T140000Z" in _ics()


def test_ics_escapa_y_usa_crlf():
    contenido = _ics()
    assert "SUMMARY:Cita en Sonrisa\\, Wari\\; prueba" in contenido
    assert "\n" not in contenido.replace("\r\n", "")
    assert contenido.endswith("END:VCALENDAR\r\n")


def test_ics_pliega_lineas_a_75_octetos_sin_romper_utf8():
    contenido = _ics(descripcion="ñ" * 200)
    for linea in contenido.split("\r\n"):
        assert len(linea.encode("utf-8")) <= 75
    assert "ñ" * 10 in contenido.replace("\r\n ", "")


def test_ics_incluye_la_secuencia_al_reprogramar():
    assert "SEQUENCE:2" in _ics(secuencia=2)
