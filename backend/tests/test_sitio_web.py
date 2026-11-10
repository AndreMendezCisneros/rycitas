"""Especificación del sitio web: secciones, publicación, SEO, seguridad, caché, fotos y medición (RW y RWN)."""
import gzip
import io
import json
import re
from datetime import timedelta
from pathlib import Path
from unittest import mock

import pytest
import requests
from django.conf import settings
from django.contrib.admin.sites import site
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import Client, override_settings
from PIL import Image

from agenda.models import Tratamiento
from citas import servicios
from citas.models import Cita, Estado
from consultorios.admin import ConsultorioForm
from consultorios.models import Consultorio
from mensajeria import tareas
from sitio import cache, metricas
from sitio.imagenes import MAX_BYTES, a_webp
from sitio.models import EventoSitio
from .conftest import AHORA, reservar

pytestmark = pytest.mark.django_db
HOST = "sonrisa.denticita.test"
CARPETA = Path(settings.BASE_DIR) / "sitio" / "static" / "sitio"
CREDENCIALES = {"CLOUDFLARE_ZONA": "zona", "CLOUDFLARE_TOKEN_CACHE": "token"}


def pedir(ruta="/", host=HOST):
    return Client().get(ruta, headers={"host": host})


def html(ruta="/", host=HOST) -> str:
    return pedir(ruta, host).content.decode()


# --- Publicación (RW-01) ----------------------------------------------------------------------------


def test_consultorio_nuevo_nace_sin_publicar(db):
    assert Consultorio._meta.get_field("publicado").default is False


def test_sin_publicar_muestra_preparacion_y_no_acepta_reservas(consultorio, limpieza):
    Consultorio.objects.update(publicado=False)
    r = pedir()
    assert r.status_code == 200
    assert "Sitio en preparación" in r.content.decode()
    assert "noindex" in r.content.decode()
    assert Client().get("/public/v1/sonrisa/perfil").status_code == 404
    assert Client().get("/public/v1/sonrisa/disponibilidad", {"motivo": "limpieza"}).status_code == 404
    assert (
        Client().post(
            "/public/v1/sonrisa/reservas",
            {"motivo": "limpieza", "inicio": "2026-11-11T09:00:00-05:00", "nombre": "Ana Paz", "celular": "987654321", "acepta_politica": True},
            content_type="application/json",
        ).status_code
        == 404
    )


def test_subdominio_inexistente_muestra_la_pagina_de_la_plataforma(db):
    r = pedir(host="nadie.denticita.test")
    assert r.status_code == 404
    assert "No encontramos esta página" in r.content.decode()


def test_al_despublicar_una_cita_existente_sigue_accesible(cliente, limpieza):
    token = reservar(cliente).json()["token"]
    Consultorio.objects.update(publicado=False)
    assert Client().get(f"/public/v1/citas/{token}").status_code == 200


# --- Contenido de la página -------------------------------------------------------------------------


def test_tiene_todas_las_secciones_de_la_especificacion(consultorio, limpieza):
    pagina = html()
    for marca in (
        'class="barra"', 'class="portada"', 'class="franja"', 'id="tratamientos"', 'id="como-reservar"', 'id="reservar"',
        'id="mis-citas"', 'id="consultorio"', 'id="horario"', 'id="preguntas"', 'class="pie"', 'id="aviso-horario"',
    ):
        assert marca in pagina, marca


def test_sin_foto_muestra_monograma_sin_el_titulo_del_doctor(consultorio):
    Consultorio.objects.update(doctor_nombre="Dra. Ana Quispe Rojas")
    pagina = html()
    assert 'class="foto monograma"' in pagina and ">AQ<" in pagina


def test_colegiatura_sin_enlace_hasta_que_exista_la_consulta_publica(consultorio):
    Consultorio.objects.update(colegiatura="12345")
    assert "Colegiatura N.º 12345" in html()
    assert 'target="_blank" rel="noopener">Colegiatura' not in html()
    with override_settings(COLEGIATURA_CONSULTA_URL="https://colegio.example/consulta"):
        assert 'href="https://colegio.example/consulta"' in html()


def test_no_nombra_a_ningun_colegio(consultorio, limpieza):
    pagina = html()
    assert "Colegio Odontológico" not in pagina and "Cirujanos Dentistas" not in pagina


def test_tarjeta_de_tratamiento_reservable_y_no_reservable(consultorio, limpieza):
    Tratamiento.objects.create(consultorio=consultorio, nombre="Implante", duracion_min=60, reservable=False)
    pagina = html()
    assert f'data-tratamiento="{limpieza.slug}"' in pagina
    assert "Se agenda tras la evaluación" in pagina
    assert 'data-tratamiento="implante"' not in pagina


def test_oculta_los_tratamientos_no_visibles(consultorio, limpieza):
    Tratamiento.objects.create(consultorio=consultorio, nombre="Secreto", duracion_min=30, visible=False)
    assert "Secreto" not in html()


def test_horario_y_datos_para_marcar_el_dia(consultorio):
    pagina = html()
    assert "9:00 a. m. a 1:00 p. m." in pagina
    assert 'data-dia="0"' in pagina
    assert "Cerrado" in pagina  # domingo


def test_siete_preguntas_que_se_abren_sin_javascript(consultorio):
    assert html().count("<details>") == 7  # incluye «¿Con cuánta anticipación llego?»


def test_el_doctor_puede_ocultar_preguntas(consultorio):
    Consultorio.objects.update(contenido_sitio={"faq_ocultas": ["pago", "dolor"]})
    pagina = html()
    assert pagina.count("<details>") == 5 and "¿Cuándo y cómo pago?" not in pagina


def test_sin_verificacion_el_sitio_explica_que_el_consultorio_escribe(consultorio):
    pagina = html()
    assert "Te escribimos por WhatsApp" in pagina
    assert "Escríbele al consultorio por WhatsApp y te ayudan a cambiarla o cancelarla." in pagina
    assert "Confirma por WhatsApp" not in pagina


@pytest.mark.verificacion_whatsapp
def test_la_pregunta_de_cancelar_usa_el_plazo_del_consultorio(consultorio):
    Consultorio.objects.update(reglas={"limite_cancelacion_horas": 24})
    assert "hasta 24 horas antes" in html()


def test_uso_de_datos_visible_en_el_pie(consultorio):
    pagina = html()
    assert "Ley N.º 29733" in pagina and 'href="/privacidad/"' in pagina


def test_contenido_del_consultorio_se_muestra_y_se_escapa(consultorio):
    Consultorio.objects.update(
        contenido_sitio={"referencias": "<b>Frente</b> al parque", "formas_de_pago": ["Yape"], "anos_practica": 9, "publico": "Niños"}
    )
    pagina = html()
    assert "&lt;b&gt;Frente&lt;/b&gt; al parque" in pagina
    assert "Yape." in pagina and "9 años de práctica · Niños" in pagina


# --- SEO y vista previa (RWN-04, RWN-05) ------------------------------------------------------------


def _datos_estructurados(pagina: str) -> dict:
    return json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', pagina, re.S).group(1))


def test_datos_estructurados_tipo_dentist(consultorio):
    datos = _datos_estructurados(html())
    assert datos["@type"] == "Dentist"
    assert datos["name"] == "Sonrisa"
    assert datos["telephone"] == "+51911111111"
    assert datos["address"]["streetAddress"] == "Jr. Prueba 1"
    assert {"@type": "OpeningHoursSpecification", "dayOfWeek": "Monday", "opens": "09:00", "closes": "13:00"} in datos["openingHoursSpecification"]


def test_los_datos_estructurados_no_permiten_romper_el_script(consultorio):
    Consultorio.objects.update(nombre="</script><script>alert(1)</script>")
    pagina = html()
    assert "<script>alert(1)" not in pagina
    assert _datos_estructurados(pagina)["name"].startswith("</script>")


def test_open_graph_titulo_y_canonica(consultorio):
    pagina = html()
    assert '<meta property="og:title" content="Sonrisa · Dra. Prueba">' in pagina
    assert "<title>Sonrisa · Dra. Prueba" in pagina
    assert f'<link rel="canonical" href="http://{HOST}/">' in pagina


def test_sitemap_y_robots_por_consultorio(consultorio):
    r = pedir("/sitemap.xml")
    assert r.status_code == 200 and r["Content-Type"] == "application/xml"
    assert f"<loc>http://{HOST}/</loc>" in r.content.decode()
    robots = html("/robots.txt")
    assert f"Sitemap: http://{HOST}/sitemap.xml" in robots
    assert "Disallow: /c/" in robots


def test_sin_publicar_no_se_indexa(consultorio):
    Consultorio.objects.update(publicado=False)
    assert pedir("/sitemap.xml").status_code == 404
    assert "Disallow: /" in html("/robots.txt")


# --- Seguridad (RWN-10) -----------------------------------------------------------------------------


def test_politica_de_contenido_sin_unsafe_inline(consultorio):
    politica = pedir()["Content-Security-Policy"]
    assert "unsafe-inline" not in politica and "unsafe-eval" not in politica
    assert "frame-ancestors 'none'" in politica
    assert "https://challenges.cloudflare.com" in politica


def test_el_hash_de_la_politica_corresponde_al_css_en_linea(consultorio):
    import base64
    import hashlib

    r = pedir()
    css = re.search(r"<style>(.*?)</style>", r.content.decode(), re.S).group(1)
    esperado = base64.b64encode(hashlib.sha256(css.encode()).digest()).decode()
    assert f"'sha256-{esperado}'" in r["Content-Security-Policy"]


def test_el_panel_no_lleva_la_politica_del_sitio(db):
    assert "Content-Security-Policy" not in pedir("/admin/login/", host="denticita.test")


def test_la_pagina_no_tiene_scripts_ni_estilos_en_atributos(consultorio, limpieza):
    pagina = html()
    assert not re.search(r"\son[a-z]+=", pagina)
    assert ' style="' not in pagina


def test_los_enlaces_de_cita_no_se_indexan(cliente, limpieza):
    token = reservar(cliente).json()["token"]
    pagina = html(f"/c/{token}/")
    assert "noindex" in pagina
    assert pedir(f"/cita/{token}/").status_code == 200


# --- Peso (RWN-01) ----------------------------------------------------------------------------------


def test_presupuesto_comprimido_y_javascript(consultorio, limpieza):
    comprimido = len(gzip.compress(pedir().content))
    comprimido += sum(len(gzip.compress(f.read_bytes())) for f in CARPETA.iterdir() if f.suffix in (".js", ".css"))
    assert comprimido <= 150 * 1024
    componente = sum(f.stat().st_size for f in CARPETA.glob("*.js") if f.name != "cita.js")
    assert componente < 60 * 1024


def _imagen(ancho=3000, alto=2000) -> io.BytesIO:
    # Ruido: el peor caso para comprimir, como una foto con mucho detalle.
    salida = io.BytesIO()
    Image.effect_noise((ancho, alto), 90).convert("RGB").save(salida, "PNG")
    salida.seek(0)
    return salida


def test_foto_grande_queda_en_webp_y_dentro_del_presupuesto():
    resultado = a_webp(_imagen())
    assert resultado.size <= MAX_BYTES
    final = Image.open(io.BytesIO(resultado.read()))
    assert final.format == "WEBP" and max(final.size) <= 1200


# --- Caché (paso 5 de «Cómo se sirve un sitio») -------------------------------------------------------


def test_sin_credenciales_no_llama_a_cloudflare(consultorio, django_capture_on_commit_callbacks):
    with mock.patch("sitio.cache.async_task") as tarea, django_capture_on_commit_callbacks(execute=True):
        consultorio.save()
    tarea.assert_not_called()


@override_settings(**CREDENCIALES)
def test_guardar_consultorio_o_tratamiento_purga_su_sitio(consultorio, django_capture_on_commit_callbacks):
    with mock.patch("sitio.cache.async_task") as tarea, django_capture_on_commit_callbacks(execute=True):
        consultorio.save()
        Tratamiento.objects.create(consultorio=consultorio, nombre="Nuevo", duracion_min=30)
    assert [c.args for c in tarea.call_args_list] == [("sitio.cache.purgar_ahora", "sonrisa")] * 2


@override_settings(**CREDENCIALES)
def test_el_horario_del_doctor_purga_el_sitio(api, django_capture_on_commit_callbacks):
    with mock.patch("sitio.cache.async_task") as tarea, django_capture_on_commit_callbacks(execute=True):
        assert api.put("/horario", {"tramos": [{"dia_semana": 0, "hora_inicio": "15:00", "hora_fin": "16:00"}]}).status_code == 200
    tarea.assert_called_once_with("sitio.cache.purgar_ahora", "sonrisa")


@override_settings(PLATAFORMA_DOMINIO="denticita.test", **CREDENCIALES)
def test_purga_solo_las_direcciones_de_ese_consultorio():
    with mock.patch("sitio.cache.requests.post") as post:
        cache.purgar_ahora("sonrisa")
    assert post.call_args.args[0].endswith("/zones/zona/purge_cache")
    assert post.call_args.kwargs["headers"]["Authorization"] == "Bearer token"
    assert all(u.startswith("https://sonrisa.denticita.test/") for u in post.call_args.kwargs["json"]["files"])


@override_settings(**CREDENCIALES)
def test_si_cloudflare_falla_no_rompe_nada():
    with mock.patch("sitio.cache.requests.post", side_effect=requests.ConnectionError):
        cache.purgar_ahora("sonrisa")


# --- Panel ------------------------------------------------------------------------------------------


def _datos_formulario(consultorio, **extra):
    datos = {
        "nombre": consultorio.nombre, "slug": consultorio.slug, "doctor_nombre": consultorio.doctor_nombre,
        "direccion": consultorio.direccion, "whatsapp": consultorio.whatsapp, "reglas": "{}", "opciones": "{}", "rubro": "odontologia", "publicado": True, "activo": True,
        "bloque_1_titulo": "Uno", "bloque_1_texto": "Texto", "bloque_2_titulo": "", "bloque_2_texto": "", "bloque_3_titulo": "", "bloque_3_texto": "",
    }
    return {**datos, **extra}


def test_el_panel_guarda_el_contenido_en_el_campo_json(consultorio):
    form = ConsultorioForm(
        _datos_formulario(consultorio, formas_de_pago="Yape, Plin ,", anos_practica=7, publico="Niños", referencias="Junto al mercado", faq_ocultas=["pago"]),
        instance=consultorio,
    )
    assert form.is_valid(), form.errors
    form.save()
    consultorio.refresh_from_db()
    assert consultorio.contenido_sitio["formas_de_pago"] == ["Yape", "Plin"]
    assert consultorio.contenido_sitio["anos_practica"] == 7
    assert consultorio.contenido_sitio["faq_ocultas"] == ["pago"]
    assert consultorio.contenido_sitio["bloques_confianza"][0] == {"titulo": "Uno", "texto": "Texto"}


def test_el_panel_convierte_las_fotos_a_webp(consultorio, tmp_path):
    subida = SimpleUploadedFile("logo.png", _imagen(400, 300).getvalue(), content_type="image/png")
    foto = SimpleUploadedFile("doc.png", _imagen(900, 900).getvalue(), content_type="image/png")
    with override_settings(MEDIA_ROOT=tmp_path, STORAGES={**settings.STORAGES, "default": {"BACKEND": "django.core.files.storage.FileSystemStorage", "OPTIONS": {"location": str(tmp_path), "base_url": "/media/"}}}):
        form = ConsultorioForm(_datos_formulario(consultorio), {"logo": subida, "foto": foto}, instance=consultorio)
        assert form.is_valid(), form.errors
        form.save()
        consultorio.refresh_from_db()
        assert consultorio.contenido_sitio["logo"].endswith(".webp")
        assert consultorio.foto.name.endswith(".webp")
        assert (tmp_path / consultorio.contenido_sitio["logo"]).stat().st_size <= MAX_BYTES


def test_el_formulario_del_panel_abre_y_muestra_metricas(consultorio, django_user_model):
    admin = django_user_model.objects.create_superuser("root@denticita.test", "clave-segura-123")
    cliente = Client()
    cliente.force_login(admin)
    r = cliente.get(f"/admin/consultorios/consultorio/{consultorio.pk}/change/", headers={"host": "denticita.test"})
    assert r.status_code == 200
    contenido = r.content.decode()
    assert "Formas de pago" in contenido and "conversion_pct" in contenido
    assert site.is_registered(Consultorio)


# --- Medición ---------------------------------------------------------------------------------------


def _evento(tipo="visita", sesion="sesion-prueba-1"):
    return Client().post("/public/v1/sonrisa/eventos", {"tipo": tipo, "sesion": sesion}, content_type="application/json")


def test_registra_eventos_sin_duplicar_por_sesion(consultorio):
    assert _evento().status_code == 204
    assert _evento().status_code == 204
    assert EventoSitio.objects.count() == 1


@pytest.mark.parametrize("tipo,sesion", [("otro", "sesion-prueba-1"), ("visita", "x"), ("visita", "<script>alert(1)</script>")])
def test_rechaza_eventos_invalidos(consultorio, tipo, sesion):
    assert _evento(tipo, sesion).status_code == 422
    assert not EventoSitio.objects.exists()


@override_settings(MAX_EVENTOS_IP_HORA=3)
def test_una_ip_no_puede_inflar_las_visitas(consultorio):
    from django.core.cache import cache as memoria

    memoria.clear()
    for n in range(6):
        assert _evento(sesion=f"sesion-inflada-{n}").status_code == 204
    assert EventoSitio.objects.count() == 3
    memoria.clear()


def test_no_mide_consultorios_sin_publicar(consultorio):
    Consultorio.objects.update(publicado=False)
    assert _evento().status_code == 404


def test_sin_verificacion_el_tiempo_termina_al_enviar_los_datos(cliente, limpieza, reloj):
    _evento("paso_1", "sesion-rapida")
    reloj.avanzar(seconds=35)
    _evento("paso_4", "sesion-rapida")
    datos = metricas.resumen(limpieza.consultorio, AHORA - timedelta(days=1), AHORA + timedelta(days=1))
    assert datos["tiempo_mediano_s"] == 35


@pytest.mark.verificacion_whatsapp
def test_metricas_del_embudo(cliente, limpieza, reloj):
    consultorio = limpieza.consultorio
    for i in range(10):
        _evento("visita", f"sesion-prueba-{i}")
    _evento("paso_1", "sesion-prueba-0")
    _evento("paso_1", "sesion-prueba-1")
    confirmada = Cita.objects.get(token_gestion=reservar(cliente).json()["token"])
    Cita.objects.filter(pk=confirmada.pk).update(estado=Estado.PROGRAMADA)
    reloj.avanzar(seconds=48)
    _evento("confirmada", "sesion-prueba-0")
    datos = metricas.resumen(consultorio, AHORA - timedelta(days=1), AHORA + timedelta(days=1))
    assert datos["visitas"] == 10 and datos["reservas_iniciadas"] == 2
    assert datos["confirmadas"] == 1
    assert datos["conversion_pct"] == 10.0 and datos["reserva_completada_pct"] == 50.0
    assert datos["tiempo_mediano_s"] == 48


def test_metricas_sin_datos_no_dividen_entre_cero(consultorio):
    datos = metricas.resumen(consultorio, AHORA - timedelta(days=1), AHORA)
    assert datos["conversion_pct"] is None and datos["tiempo_mediano_s"] is None


def test_la_limpieza_borra_los_eventos_viejos(consultorio, reloj):
    _evento()
    reloj.avanzar(days=91)
    _evento(sesion="sesion-reciente")
    tareas.limpieza_diaria()
    assert list(EventoSitio.objects.values_list("sesion", flat=True)) == ["sesion-reciente"]


# --- Mensajes de la especificación ------------------------------------------------------------------


def test_mensajes_de_validacion_y_de_horario_ocupado():
    with pytest.raises(Exception, match="Debe ser un celular peruano de 9 dígitos que empiece con 9."):
        servicios.normalizar_celular("123")
    assert "Ese horario acaba de ocuparse" in servicios._horario_tomado().mensaje


def test_acepta_celular_con_o_sin_prefijo_y_espacios():
    for valor in ("987654321", "+51 987 654 321", "51987654321"):
        assert servicios.normalizar_celular(valor) == "+51987654321"
