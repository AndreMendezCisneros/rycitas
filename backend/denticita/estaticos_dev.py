"""Solo con DEBUG: los estáticos llevan ?v=<fecha de modificación> en la URL.

En desarrollo no tienen hash en el nombre (en producción sí, con el manifiesto de WhiteNoise). Sin esto, el navegador
sigue usando el JS y el CSS viejos tras un cambio, sobre todo dentro de la ventana de reserva del sitio propio.
"""
import os

from django.contrib.staticfiles import finders
from django.contrib.staticfiles.storage import StaticFilesStorage


class EstaticosDesarrollo(StaticFilesStorage):
    def url(self, name):
        url = super().url(name)
        ruta = finders.find(name) if name else None
        if isinstance(ruta, str) and os.path.exists(ruta):
            return f"{url}?v={int(os.path.getmtime(ruta))}"
        return url
