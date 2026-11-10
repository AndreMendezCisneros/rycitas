"""Solo con DEBUG: permite probar la versión web de la app (flutter run -d chrome) contra el backend local.

En producción no hace falta: Caddy sirve la app web y /api/v1 desde el mismo host.
"""
from django.http import HttpResponse


class CorsDesarrolloMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        origen = request.headers.get("Origin", "")
        permitido = origen.startswith(("http://localhost:", "http://127.0.0.1:"))
        if request.method == "OPTIONS" and permitido:
            respuesta = HttpResponse(status=204)
        else:
            respuesta = self.get_response(request)
        if permitido:
            respuesta["Access-Control-Allow-Origin"] = origen
            respuesta["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Idempotency-Key, X-Request-ID"
            respuesta["Access-Control-Expose-Headers"] = "X-Request-ID"
            respuesta["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        return respuesta
