"""Errores de negocio con un código estable que el sitio y la app pueden interpretar."""
from django.http import JsonResponse


class ErrorNegocio(Exception):
    def __init__(self, codigo: str, mensaje: str, status: int = 400, **extra):
        super().__init__(mensaje)
        self.codigo = codigo
        self.mensaje = mensaje
        self.status = status
        self.extra = extra


def registrar_errores(api) -> None:
    @api.exception_handler(ErrorNegocio)
    def _error_negocio(request, exc: ErrorNegocio):
        return JsonResponse({"codigo": exc.codigo, "detail": exc.mensaje, **exc.extra}, status=exc.status)
