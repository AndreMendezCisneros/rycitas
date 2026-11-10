"""CSS esencial en línea y política de contenido (RWN-10). La política autoriza ese CSS por su hash, no con 'unsafe-inline'."""
import base64
import hashlib
from functools import lru_cache
from pathlib import Path

from django.conf import settings

RUTA_ESENCIAL = Path(__file__).parent / "static" / "sitio" / "esencial.css"
SIN_POLITICA = ("/admin", "/api/", "/public/", "/webhooks/")


@lru_cache(maxsize=1)
def _esencial_guardado() -> str:
    return RUTA_ESENCIAL.read_bytes().decode()


def css_esencial() -> str:
    return RUTA_ESENCIAL.read_bytes().decode() if settings.DEBUG else _esencial_guardado()


def politica_contenido(marcos: str = "'none'") -> str:
    """`marcos`: quién puede mostrar la página en un iframe. Solo `/reservar/` lo abre, al propio sitio."""
    resumen = base64.b64encode(hashlib.sha256(css_esencial().encode()).digest()).decode()
    return "; ".join(
        [
            "default-src 'self'",
            "script-src 'self' https://challenges.cloudflare.com https://static.cloudflareinsights.com",
            f"style-src 'self' 'sha256-{resumen}' https://fonts.googleapis.com",
            "font-src https://fonts.gstatic.com",
            "img-src 'self' data:",
            "connect-src 'self' https://cloudflareinsights.com",
            "frame-src https://challenges.cloudflare.com",
            "base-uri 'self'",
            "form-action 'self'",
            f"frame-ancestors {marcos}",
            "object-src 'none'",
        ]
    )


class PoliticaContenidoMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        respuesta = self.get_response(request)
        if not request.path.startswith(SIN_POLITICA):
            # Una vista puede traer su propia política (los sitios propios, la reserva embebible).
            respuesta["Content-Security-Policy"] = getattr(respuesta, "politica_contenido", None) or politica_contenido()
            respuesta["Referrer-Policy"] = "strict-origin-when-cross-origin"
        return respuesta
