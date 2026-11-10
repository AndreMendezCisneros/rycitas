"""Identificador de cada petición y su origen (mejora 12 del análisis RYJEC).

Queda en los logs y en cada `EventoCita`: así un reclamo («yo no cancelé esa cita») se sigue de punta a punta.
Fuera de una petición (tareas programadas) el origen es «sistema».
"""
from __future__ import annotations

import re
import uuid
from contextvars import ContextVar

request_id: ContextVar[str] = ContextVar("request_id", default="")
origen: ContextVar[str] = ContextVar("origen", default="sistema")

_VALIDO = re.compile(r"^[A-Za-z0-9-]{8,36}$")


def origen_de_ruta(ruta: str) -> str:
    if ruta.startswith("/api/"):
        return "app"
    if ruta.startswith("/panel/") or ruta.startswith("/admin/"):
        return "panel"
    return "sitio"


class ContextoMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        entrante = request.headers.get("X-Request-ID", "")
        rid = entrante if _VALIDO.match(entrante) else str(uuid.uuid4())
        t1, t2 = request_id.set(rid), origen.set(origen_de_ruta(request.path))
        try:
            respuesta = self.get_response(request)
        finally:
            request_id.reset(t1)
            origen.reset(t2)
        respuesta["X-Request-ID"] = rid
        return respuesta
