"""Resuelve el consultorio a partir del subdominio: <slug>.<dominio de la plataforma>."""
from django.conf import settings
from django.http import Http404
from django.shortcuts import render

from consultorios.models import Consultorio


def slug_desde_host(host: str) -> str | None:
    host = host.split(":")[0].lower()
    sufijo = f".{settings.PLATAFORMA_DOMINIO}"
    if not host.endswith(sufijo):
        return None
    slug = host[: -len(sufijo)]
    if not slug or "." in slug or slug in settings.SUBDOMINIOS_RESERVADOS:
        return None
    return slug


class ConsultorioMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.consultorio = None
        slug = slug_desde_host(request.get_host())
        if slug:
            request.consultorio = Consultorio.objects.filter(slug=slug, activo=True).first()
            if request.consultorio is None:
                return render(request, "404.html", status=404)  # la página de la plataforma, también en desarrollo
            if request.path.startswith(("/admin", "/panel")):  # los paneles no se exponen en los sitios de negocios
                raise Http404()
        return self.get_response(request)
