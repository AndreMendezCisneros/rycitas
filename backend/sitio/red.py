from django.conf import settings


def ip_cliente(request) -> str:
    """IP real del visitante. El encabezado de Cloudflare solo vale si el origen acepta tráfico únicamente de
    Cloudflare (ver deploy/README); si no, cualquiera podría falsificarlo para saltarse el límite."""
    if settings.CONFIAR_CLOUDFLARE:
        ip = request.headers.get("CF-Connecting-IP")
        if ip:
            return ip
    return request.META.get("REMOTE_ADDR", "")
