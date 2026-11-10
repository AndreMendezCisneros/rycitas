import json
from pathlib import Path

from django.conf import settings
from django.core.files.storage import default_storage
from django.db import connection
from django.http import Http404, HttpResponse, JsonResponse
from django.shortcuts import redirect, render
from django.urls import Resolver404, resolve
from django.views.decorators.cache import never_cache
from django.views.decorators.clickjacking import xframe_options_sameorigin
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from citas import presentacion, servicios
from denticita.errores import ErrorNegocio
from sitio import contenido as contenido_fijo
from sitio import propios
from sitio.seguridad import politica_contenido

RUTA_WIDGET = Path(__file__).parent / "static" / "sitio" / "rycitas.js"

DIAS_SCHEMA = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
TIPO_SCHEMA = {
    "odontologia": "Dentist",
    "barberia": "HairSalon",
    "peluqueria": "BeautySalon",
    "estetica": "DaySpa",
    "salud": "MedicalBusiness",
    "veterinaria": "VeterinaryCare",
}


def _cacheable(respuesta: HttpResponse) -> HttpResponse:
    # Cloudflare guarda 5 min; al cambiar los datos del consultorio se purga (sitio/cache.py).
    respuesta["Cache-Control"] = "public, s-maxage=300, max-age=0"
    return respuesta


def _datos_estructurados(request, consultorio, perfil: dict, imagen: str) -> str:
    """schema.org/Dentist (RWN-04). Se escapa «<» para que ningún dato pueda cerrar la etiqueta <script>."""
    apertura = [
        {
            "@type": "OpeningHoursSpecification",
            "dayOfWeek": DIAS_SCHEMA[dia["dia_semana"]],
            "opens": abre,
            "closes": cierra,
        }
        for dia in perfil["horario"]
        for abre, cierra in dia["rangos"]
    ]
    datos = {
        "@context": "https://schema.org",
        "@type": TIPO_SCHEMA.get(consultorio.rubro, "LocalBusiness"),
        "name": consultorio.nombre,
        "url": request.build_absolute_uri("/"),
        "telephone": f"+{consultorio.whatsapp}",
        "address": {"@type": "PostalAddress", "streetAddress": consultorio.direccion, "addressCountry": "PE"},
        "openingHoursSpecification": apertura,
    }
    if imagen:
        datos["image"] = imagen
    return json.dumps(datos, ensure_ascii=False).replace("<", "\\u003c")


def _url_archivo(ruta: str) -> str:
    return default_storage.url(ruta) if ruta else ""


def _equipo(consultorio, perfil: dict) -> list[dict]:
    """Con agenda compartida, la tarjeta de siempre (datos del negocio); con varios, una por profesional."""
    if consultorio.opciones_efectivas["modo_agenda"] != "por_profesional" or len(perfil["profesionales"]) <= 1:
        return []
    return perfil["profesionales"]


def _contexto_sitio(request, consultorio) -> dict:
    perfil = presentacion.perfil_publico(consultorio)
    contenido = consultorio.contenido
    tipo = consultorio.tipo
    voc = consultorio.vocabulario
    ejemplo = next((m["nombre"] for m in perfil["motivos"]), voc["servicio"])
    foto_consultorio = _url_archivo(contenido["foto_consultorio"])
    imagen = perfil["foto"] or foto_consultorio
    imagen = request.build_absolute_uri(imagen) if imagen else ""
    return {
        "c": perfil,
        "contenido": contenido,
        "logo": _url_archivo(contenido["logo"]),
        "foto_consultorio": foto_consultorio,
        "iniciales": consultorio.iniciales_doctor,
        "pasos_reserva": contenido_fijo.pasos_reserva(consultorio),
        "voc": voc,
        "tipo": tipo,
        "rubro": consultorio.rubro,
        "equipo": _equipo(consultorio, perfil),
        "titulo_seo": tipo["titulo"][0].removesuffix(" en"),
        "ejemplo_servicio": ejemplo,
        "suspendido": consultorio.suspendido,
        "preguntas": contenido_fijo.preguntas_visibles(consultorio),
        "colegiatura_url": settings.COLEGIATURA_CONSULTA_URL,
        "descripcion": f"{perfil['nombre']} en {perfil['direccion']}. {tipo['titulo'][0]} línea en menos de un minuto.",
        "url_canonica": request.build_absolute_uri("/"),
        "imagen": imagen,
        "datos_estructurados": _datos_estructurados(request, consultorio, perfil, imagen),
        "analitica": settings.CLOUDFLARE_ANALYTICS_TOKEN,
        "config": {
            "slug": perfil["slug"],
            "motivos": perfil["motivos"],
            "horario": [{"dia_semana": d["dia_semana"], "rangos": d["rangos"]} for d in perfil["horario"]],
            "whatsapp": perfil["whatsapp"],
            "dias_maximos": consultorio.reglas_efectivas["dias_maximos"],
            "turnstile": settings.TURNSTILE_SITE_KEY,
            "demo": settings.DEBUG and settings.VERIFICACION_WHATSAPP,
            "voc": voc,
            "pregunta_servicio": tipo["pregunta_servicio"],
            "profesionales": perfil["profesionales"],
            "opciones": perfil["opciones"],
            "acepta_reservas": perfil["acepta_reservas"],
            "nombre": perfil["nombre"],
            "acento": contenido.get("color_acento") or tipo.get("color", ""),
        },
    }


def inicio(request):
    consultorio = request.consultorio
    if consultorio is None:
        return _cacheable(render(request, "sitio/plataforma.html"))
    if not consultorio.publicado:
        return _cacheable(render(request, "sitio/preparacion.html", {"consultorio": consultorio}))
    if propios.carpeta(consultorio):
        return propios.responder(consultorio, "")
    return _cacheable(render(request, "sitio/consultorio.html", _contexto_sitio(request, consultorio)))


@xframe_options_sameorigin
def reservar(request):
    """La reserva sola, a pantalla completa: el enlace directo que manda el dueño y lo que abre el widget."""
    consultorio = request.consultorio
    if consultorio is None:
        raise Http404()
    if not consultorio.publicado:
        return _cacheable(render(request, "sitio/preparacion.html", {"consultorio": consultorio}))
    contexto = _contexto_sitio(request, consultorio)
    contexto["embebida"] = request.GET.get("embed") == "1"
    contexto["volver_a"] = "/" if propios.carpeta(consultorio) or not contexto["embebida"] else ""
    respuesta = _cacheable(render(request, "sitio/reservar.html", contexto))
    respuesta.politica_contenido = politica_contenido(marcos="'self'")
    return respuesta


def widget(request):
    """`/rycitas.js`: cualquier sitio lo incluye y sus botones «Agendar cita» abren la reserva encima."""
    respuesta = HttpResponse(RUTA_WIDGET.read_bytes(), content_type="text/javascript; charset=utf-8")
    respuesta["Cache-Control"] = "public, max-age=300"
    return respuesta


def sitio_propio(request, ruta: str):
    """Último recurso de las rutas: las páginas y archivos del sitio propio del negocio."""
    # Las rutas de RyCitas ganan siempre: «/privacidad» redirige a «/privacidad/», como antes.
    if ruta and not ruta.endswith("/"):
        try:
            if resolve(f"/{ruta}/").func is not sitio_propio:
                return redirect(f"/{ruta}/", permanent=True)
        except Resolver404:
            pass
    consultorio = request.consultorio
    if consultorio is None or not consultorio.publicado or not propios.carpeta(consultorio):
        raise Http404()
    return propios.responder(consultorio, ruta)


def sitemap(request):
    if request.consultorio is None or not request.consultorio.publicado:
        raise Http404()
    urls = [request.build_absolute_uri("/"), request.build_absolute_uri("/privacidad/")]
    return _cacheable(render(request, "sitio/sitemap.xml", {"urls": urls}, content_type="application/xml"))


def robots(request):
    if request.consultorio is None or not request.consultorio.publicado:
        return _cacheable(HttpResponse("User-agent: *\nDisallow: /\n", content_type="text/plain"))
    # Los enlaces de citas son privados: no deben indexarse aunque alguien los publique.
    texto = f"User-agent: *\nDisallow: /c/\nDisallow: /cita/\nSitemap: {request.build_absolute_uri('/sitemap.xml')}\n"
    return _cacheable(HttpResponse(texto, content_type="text/plain"))


@never_cache
def mi_cita(request, token: str):
    try:
        cita = servicios.obtener_por_token(token)
    except ErrorNegocio as error:
        return render(request, "sitio/enlace_invalido.html", {"mensaje": error.mensaje}, status=error.status)
    return render(
        request,
        "sitio/cita.html",
        {
            "consultorio": cita.consultorio,
            "config": {"token": token, "demo": settings.DEBUG and settings.VERIFICACION_WHATSAPP},
        },
    )


def privacidad(request):
    from consultorios.rubros import rubro

    consultorio = request.consultorio
    contexto = {
        "consultorio": consultorio,
        "voc": consultorio.vocabulario if consultorio else rubro("otro")["vocabulario"],
        "salud": consultorio.tipo["salud"] if consultorio else False,
    }
    return _cacheable(render(request, "sitio/privacidad.html", contexto))


@never_cache
def salud(request):
    """Para el monitor externo (RNF-05): falla si la base no responde."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception:
        return JsonResponse({"estado": "error"}, status=503)
    return JsonResponse({"estado": "ok"})


@csrf_exempt
@require_POST
def simular_whatsapp(request, token: str):
    """Solo con DEBUG (ver urls.py): reemplaza a Meta para probar el flujo sin una cuenta de WhatsApp."""
    if not settings.DEBUG or not settings.VERIFICACION_WHATSAPP:
        raise Http404()
    cita = servicios.obtener_por_token(token)
    servicios.confirmar_por_whatsapp(cita.paciente.celular, servicios.mensaje_verificacion(cita))
    return JsonResponse({"ok": True})
