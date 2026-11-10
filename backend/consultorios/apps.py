from django.apps import AppConfig


class ConsultoriosConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "consultorios"

    def ready(self):
        from denticita import checks  # noqa: F401
