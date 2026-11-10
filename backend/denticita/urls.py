from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path, re_path

from denticita.api import api_cliente, api_doctor, api_publica
from mensajeria.webhook import webhook_whatsapp
from sitio import views as sitio

urlpatterns = [
    path("admin/", admin.site.urls),
    path("panel/", include("panel.urls")),
    path("public/v1/", api_publica.urls),
    path("api/v1/", api_doctor.urls),
    path("cliente/v1/", api_cliente.urls),
    path("webhooks/whatsapp", webhook_whatsapp, name="webhook-whatsapp"),
    path("salud/", sitio.salud, name="salud"),
    path("privacidad/", sitio.privacidad, name="privacidad"),
    path("c/<str:token>/", sitio.mi_cita, name="mi-cita"),
    path("cita/<str:token>/", sitio.mi_cita),  # enlaces ya enviados con la ruta anterior
    path("sitemap.xml", sitio.sitemap, name="sitemap"),
    path("robots.txt", sitio.robots, name="robots"),
    path("reservar/", sitio.reservar, name="reservar"),
    path("rycitas.js", sitio.widget, name="widget"),
    path("", sitio.inicio, name="inicio"),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns.append(path("dev/simular-whatsapp/<str:token>/", sitio.simular_whatsapp))

# Siempre al final: lo que no es de RyCitas es del sitio propio del negocio (si tiene uno).
urlpatterns.append(re_path(r"^(?P<ruta>(?!static/|media/).*)$", sitio.sitio_propio))
