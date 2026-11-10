from django.apps import AppConfig


class SitioConfig(AppConfig):
    name = "sitio"

    def ready(self):
        from sitio import cache

        cache.conectar_senales()
