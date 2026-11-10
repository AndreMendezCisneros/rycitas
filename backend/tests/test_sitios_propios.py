"""RyCitas en el sitio propio de cada negocio: /reservar/, el widget /rycitas.js y el sitio compilado del negocio."""
import pytest
from django.test import Client

from panel.formularios import SitioForm
from sitio import propios

from .conftest import crear_consultorio

pytestmark = pytest.mark.django_db
HOST = "sonrisa.denticita.test"


def sitio(ruta="/", host=HOST):
    return Client().get(ruta, headers={"host": host})


@pytest.fixture
def carpeta_sitios(tmp_path, settings):
    """Un sitio compilado mínimo, como el que deja `scripts/sitio.ps1`."""
    settings.SITIOS_PROPIOS_DIR = tmp_path
    raiz = tmp_path / "belleza"
    (raiz / "assets").mkdir(parents=True)
    (raiz / "index.html").write_text('<!doctype html><title>Belleza</title><script src="/rycitas.js" defer></script>', "utf-8")
    (raiz / "assets" / "index-AbCdEf12.js").write_text("console.log('hola')", "utf-8")
    (raiz / "logo.png").write_bytes(b"\x89PNG")
    (tmp_path / "secreto.txt").write_text("no", "utf-8")
    return tmp_path


@pytest.fixture
def con_sitio_propio(consultorio, carpeta_sitios):
    consultorio.sitio_propio = "belleza"
    consultorio.save()
    return consultorio


# --- /reservar/ ------------------------------------------------------------------------------------------------------

def test_reservar_es_la_reserva_sola(consultorio, limpieza):
    r = sitio("/reservar/")
    assert r.status_code == 200
    html = r.content.decode()
    assert 'id="paso"' in html and "reserva.js" in html and "reservar.css" in html
    assert "Reservas con <strong>RyCitas</strong>" in html
    assert 'name="robots" content="noindex"' in html


def test_reservar_se_puede_embeber_solo_en_el_mismo_sitio(consultorio, limpieza):
    r = sitio("/reservar/?embed=1")
    assert "frame-ancestors 'self'" in r["Content-Security-Policy"]
    assert r["X-Frame-Options"] == "SAMEORIGIN"
    assert 'id="rv-cerrar"' in r.content.decode()
    # El resto del sitio sigue sin poder mostrarse en un iframe.
    assert "frame-ancestors 'none'" in sitio("/")["Content-Security-Policy"]


def test_reservar_lleva_el_color_del_negocio(consultorio, limpieza):
    consultorio.contenido_sitio = {"color_acento": "#32b8c6"}
    consultorio.save()
    assert '"acento": "#32b8c6"' in sitio("/reservar/").content.decode()


def test_reservar_sin_negocio_o_sin_publicar(db, consultorio):
    assert sitio("/reservar/", host="denticita.test").status_code == 404
    consultorio.publicado = False
    consultorio.save()
    assert "preparación" in sitio("/reservar/").content.decode()


def test_widget_se_sirve_como_javascript(consultorio):
    r = sitio("/rycitas.js")
    assert r.status_code == 200
    assert r["Content-Type"].startswith("text/javascript")
    assert b"data-rycitas-reservar" in r.content and b"window.RyCitas" in r.content


# --- Sitio propio ----------------------------------------------------------------------------------------------------

def test_sin_sitio_propio_se_ve_la_landing(consultorio, limpieza, carpeta_sitios):
    html = sitio("/").content.decode()
    assert "Reserva tu cita" in html
    assert sitio("/tratamientos").status_code == 404


def test_sitio_propio_en_la_portada(con_sitio_propio):
    r = sitio("/")
    assert r.status_code == 200
    assert b"<title>Belleza</title>" in b"".join(r.streaming_content)
    assert "'unsafe-inline'" in r["Content-Security-Policy"]  # estilos de React/Tailwind
    assert "frame-ancestors 'none'" in r["Content-Security-Policy"]


def test_sitio_propio_rutas_de_la_aplicacion_caen_a_index(con_sitio_propio):
    r = sitio("/tratamientos")
    assert r.status_code == 200 and b"Belleza" in b"".join(r.streaming_content)


def test_sitio_propio_assets_con_cache_larga(con_sitio_propio):
    r = sitio("/assets/index-AbCdEf12.js")
    assert r.status_code == 200
    assert "immutable" in r["Cache-Control"]
    assert r["Content-Type"] in ("text/javascript", "application/javascript")
    assert "max-age=3600" in sitio("/logo.png")["Cache-Control"]


def test_asset_inexistente_es_404_y_no_la_portada(con_sitio_propio):
    assert sitio("/assets/no-existe.js").status_code == 404


@pytest.mark.parametrize("ruta", ["/../secreto.txt", "/%2e%2e/secreto.txt", "/assets/..%2f..%2fsecreto.txt", "/..\\secreto.txt"])
def test_no_sale_de_la_carpeta_del_sitio(con_sitio_propio, ruta):
    r = sitio(ruta)
    contenido = b"".join(r.streaming_content) if r.streaming else r.content
    assert b"no" != contenido.strip()
    assert r.status_code in (200, 301, 404)
    if r.status_code == 200:
        assert b"Belleza" in contenido  # a lo sumo, la portada del propio sitio


def test_las_rutas_de_rycitas_ganan_al_sitio_propio(con_sitio_propio, limpieza):
    assert b'id="paso"' in sitio("/reservar/").content
    assert sitio("/reservar")["Location"] == "/reservar/"
    assert sitio("/privacidad")["Location"] == "/privacidad/"
    assert sitio("/c/token-falso/").status_code == 404
    assert sitio("/public/v1/sonrisa/perfil").status_code == 200
    assert b"window.RyCitas" in sitio("/rycitas.js").content


def test_carpeta_inexistente_vuelve_a_la_landing(consultorio, limpieza, carpeta_sitios):
    consultorio.sitio_propio = "no-compilado"
    consultorio.save()
    assert "Reserva tu cita" in sitio("/").content.decode()


def test_un_negocio_no_ve_el_sitio_propio_de_otro(con_sitio_propio, otro_consultorio):
    r = sitio("/", host="ajeno.denticita.test")
    assert not r.streaming and "Consultorio Ajeno" in r.content.decode()


def test_slug_invalido_nunca_se_sirve(consultorio, carpeta_sitios):
    consultorio.sitio_propio = "../belleza"
    assert propios.carpeta(consultorio) is None


def test_panel_ofrece_solo_sitios_compilados(consultorio, carpeta_sitios):
    (carpeta_sitios / "sin-index").mkdir()
    opciones = dict(SitioForm(instance=consultorio).fields["sitio_propio"].choices)
    assert set(opciones) == {"", "belleza"}
    consultorio.sitio_propio = "perdido"
    opciones = dict(SitioForm(instance=consultorio).fields["sitio_propio"].choices)
    assert "no está compilado" in opciones["perdido"]


def test_sitio_propio_sin_publicar_muestra_preparacion(db, carpeta_sitios):
    c = crear_consultorio(slug="nuevo", nombre="Nuevo", sitio_propio="belleza")
    c.publicado = False
    c.save()
    assert "preparación" in sitio("/", host="nuevo.denticita.test").content.decode()
    assert sitio("/tratamientos", host="nuevo.denticita.test").status_code == 404
