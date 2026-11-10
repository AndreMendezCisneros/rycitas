from django.urls import path

from panel import vistas

app_name = "panel"

urlpatterns = [
    path("", vistas.lista, name="lista"),
    path("entrar/", vistas.entrar, name="entrar"),
    path("salir/", vistas.salir, name="salir"),
    path("nuevo/", vistas.nuevo, name="nuevo"),
    path("n/<int:pk>/", vistas.ficha, name="ficha"),
    path("n/<int:pk>/accion/<str:nombre>/", vistas.accion, name="accion"),
    path("n/<int:pk>/cuenta/<int:usuario_id>/<str:nombre>/", vistas.accion_cuenta, name="accion_cuenta"),
    path("n/<int:pk>/exportar/<str:que>.csv", vistas.exportar, name="exportar"),
]
