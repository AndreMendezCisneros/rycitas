"""Sitios web completos de cada negocio (por ejemplo, uno hecho en React), servidos en su subdominio.

El sitio es del negocio; RyCitas solo entra cuando el cliente toca «Agendar cita»: el sitio incluye `/rycitas.js` y
ese script abre `/reservar/` encima de la página. Las rutas de RyCitas (`/reservar/`, `/c/`, `/public/`...) se
resuelven antes que este fallback, así que un sitio propio nunca puede taparlas.
"""
import mimetypes
import re
from pathlib import Path

from django.conf import settings
from django.http import FileResponse, Http404

SLUG_VALIDO = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
# Vite y la mayoría de empaquetadores ponen un hash en el nombre: se pueden guardar un año.
ASSET_CON_HASH = re.compile(r"[-.][A-Za-z0-9_]{8,}\.(js|css|woff2?|png|jpe?g|webp|svg|avif|gif)$")


def politica_contenido() -> str:
    """Más abierta que la de la landing: estos sitios traen estilos en línea (React, Tailwind) e imágenes externas."""
    return "; ".join(
        [
            "default-src 'self'",
            "script-src 'self'",
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
            "font-src 'self' data: https://fonts.gstatic.com",
            "img-src 'self' data: blob: https:",
            "media-src 'self' https:",
            "connect-src 'self'",
            "frame-src 'self' https://www.google.com https://www.youtube.com https://www.youtube-nocookie.com",
            "base-uri 'self'",
            "form-action 'self'",
            "frame-ancestors 'none'",
            "object-src 'none'",
        ]
    )


def disponibles() -> list[str]:
    """Carpetas compiladas que tienen `index.html`: son las que el panel ofrece."""
    raiz = Path(settings.SITIOS_PROPIOS_DIR)
    if not raiz.is_dir():
        return []
    return sorted(d.name for d in raiz.iterdir() if d.is_dir() and SLUG_VALIDO.match(d.name) and (d / "index.html").is_file())


def carpeta(consultorio) -> Path | None:
    nombre = consultorio.sitio_propio if consultorio else ""
    if not nombre or not SLUG_VALIDO.match(nombre):
        return None
    ruta = Path(settings.SITIOS_PROPIOS_DIR) / nombre
    return ruta if (ruta / "index.html").is_file() else None


def _dentro(raiz: Path, ruta: str) -> Path | None:
    """Nunca sale de la carpeta del sitio: ni con «..», ni con rutas absolutas, ni con enlaces simbólicos."""
    if "\x00" in ruta or "\\" in ruta:
        return None
    destino = (raiz / ruta.lstrip("/")).resolve()
    raiz = raiz.resolve()
    if destino != raiz and raiz not in destino.parents:
        return None
    return destino


def responder(consultorio, ruta: str):
    """El archivo pedido; si es una ruta de la aplicación (sin extensión), `index.html` para que su router la pinte."""
    raiz = carpeta(consultorio)
    if raiz is None:
        raise Http404()
    archivo = _dentro(raiz, ruta) if ruta else raiz / "index.html"
    if archivo is None:
        raise Http404()
    if archivo.is_dir():
        archivo = archivo / "index.html"
    if not archivo.is_file():
        if Path(ruta).suffix:  # un asset que no existe es un 404 de verdad, no la portada
            raise Http404()
        archivo = raiz / "index.html"
    tipo, _ = mimetypes.guess_type(archivo.name)
    respuesta = FileResponse(archivo.open("rb"), content_type=tipo or "application/octet-stream")
    if archivo.name == "index.html":
        respuesta["Cache-Control"] = "public, max-age=0, s-maxage=300"
    elif ASSET_CON_HASH.search(archivo.name):
        respuesta["Cache-Control"] = "public, max-age=31536000, immutable"
    else:
        respuesta["Cache-Control"] = "public, max-age=3600"
    respuesta["X-Content-Type-Options"] = "nosniff"
    respuesta.politica_contenido = politica_contenido()
    return respuesta
