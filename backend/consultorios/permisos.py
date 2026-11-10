"""Permisos dentro de un negocio: la cuenta general configura; la de cada profesional solo atiende su agenda."""
from denticita.errores import ErrorNegocio


def solo_general(request, mensaje: str = "Solo la cuenta general del negocio puede hacer esto.") -> None:
    """Corta con 403 si quien llama es la cuenta de un profesional (SEG-03)."""
    if request.auth.profesional_id:
        raise ErrorNegocio("solo_general", mensaje, 403)
