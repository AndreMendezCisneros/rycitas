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


_CAMPOS_PETICION_SENSIBLES = ("data", "cookies", "query_string", "headers", "env")


def sin_datos_personales(evento: dict, _pista: dict) -> dict:
    """Filtro final antes de enviar un error a Sentry (SEG-14, DAT-08).

    Quita el cuerpo, las cookies, los encabezados y la consulta de la petición, y enmascara los tokens de
    `/c/<token>/` en la URL: con ellos se cancela una cita ajena.
    """
    import re

    peticion = evento.get("request") or {}
    for campo in _CAMPOS_PETICION_SENSIBLES:
        peticion.pop(campo, None)
    if "url" in peticion:
        url = peticion["url"].split("?", 1)[0]  # la consulta puede llevar la firma del enlace de WhatsApp
        peticion["url"] = re.sub(r"/(c|cita|citas)/[^/#]+", r"/\1/***", url)
    evento.pop("user", None)
    return evento
