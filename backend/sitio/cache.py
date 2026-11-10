"""Borra de Cloudflare la copia de un sitio cuando cambian sus datos. Sin credenciales no hace nada."""
import logging

import requests
from django.conf import settings
from django.db import transaction
from django.db.models.signals import post_delete, post_save
from django_q.tasks import async_task

registro = logging.getLogger(__name__)


def urls_del_sitio(slug: str) -> list[str]:
    base = f"https://{slug}.{settings.PLATAFORMA_DOMINIO}"
    return [f"{base}/", f"{base}/sitemap.xml", f"{base}/public/v1/{slug}/perfil"]


def purgar_ahora(slug: str) -> None:
    try:
        respuesta = requests.post(
            f"https://api.cloudflare.com/client/v4/zones/{settings.CLOUDFLARE_ZONA}/purge_cache",
            headers={"Authorization": f"Bearer {settings.CLOUDFLARE_TOKEN_CACHE}"},
            json={"files": urls_del_sitio(slug)},
            timeout=10,
        )
        respuesta.raise_for_status()
    except requests.RequestException as error:
        # No es grave: la copia vence sola a los 5 minutos.
        registro.warning("no se pudo purgar la caché de %s: %s", slug, error)


def purgar_sitio(slug: str) -> None:
    if settings.CLOUDFLARE_ZONA and settings.CLOUDFLARE_TOKEN_CACHE:
        transaction.on_commit(lambda: async_task("sitio.cache.purgar_ahora", slug))


def _al_cambiar_consultorio(sender, instance, **kwargs):
    purgar_sitio(instance.slug)


def _al_cambiar_tratamiento(sender, instance, **kwargs):
    purgar_sitio(instance.consultorio.slug)


def conectar_senales() -> None:
    """El horario no pasa por aquí: se guarda con bulk_create, sin señales, y lo purga quien lo guarda."""
    from agenda.models import Tratamiento
    from consultorios.models import Consultorio

    post_save.connect(_al_cambiar_consultorio, sender=Consultorio, dispatch_uid="purga_consultorio")
    post_delete.connect(_al_cambiar_consultorio, sender=Consultorio, dispatch_uid="purga_consultorio_borrado")
    post_save.connect(_al_cambiar_tratamiento, sender=Tratamiento, dispatch_uid="purga_tratamiento")
    post_delete.connect(_al_cambiar_tratamiento, sender=Tratamiento, dispatch_uid="purga_tratamiento_borrado")
