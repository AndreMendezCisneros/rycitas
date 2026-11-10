"""Login del panel y de /admin (sesión de Django) con límite de intentos (SEG-05).

Toda autenticación por formulario pasa por aquí: el panel usa `AuthenticationForm` y el admin su propio formulario,
y ambos llaman a `authenticate()`. Dos frenos, igual que el login de la app (consultorios.autenticacion):
- por cuenta: tras LOGIN_MAX_INTENTOS fallidos espera LOGIN_ESPERA_MINUTOS, incluso con la clave correcta;
- por IP: más de PANEL_MAX_INTENTOS_IP_HORA fallos en una hora cortan todo intento desde esa IP.
La respuesta es la misma en todos los casos («correo o clave incorrectos»): no revela qué cuentas existen.
"""
from __future__ import annotations

import hashlib
import hmac
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend
from django.core.exceptions import PermissionDenied
from django.utils import timezone

from citas.models import IntentoReserva
from sitio.red import ip_cliente


def _hash_ip(ip: str) -> str:
    # Prefijo propio: los fallos de login no se mezclan con los intentos de reserva de la misma tabla.
    return hmac.new(settings.SECRET_KEY.encode(), f"login:{ip}".encode(), hashlib.sha256).hexdigest()


class AccesoConLimite(ModelBackend):
    def authenticate(self, request, username=None, password=None, **kwargs):
        Usuario = get_user_model()
        correo = username or kwargs.get(Usuario.USERNAME_FIELD)
        if correo is None or password is None:
            return None
        ahora = timezone.now()
        ip_hash = _hash_ip(ip_cliente(request)) if request is not None else None
        if ip_hash:
            fallos = IntentoReserva.objects.filter(ip_hash=ip_hash, creado_en__gte=ahora - timedelta(hours=1)).count()
            if fallos >= settings.PANEL_MAX_INTENTOS_IP_HORA:
                raise PermissionDenied  # authenticate() deja de probar otros backends y devuelve None

        usuario = Usuario.objects.filter(correo__iexact=correo.strip()).first()
        if usuario is not None and usuario.bloqueado_hasta and usuario.bloqueado_hasta > ahora:
            Usuario().set_password(password)  # mismo costo que una verificación real
            return None

        resultado = super().authenticate(request, username=correo, password=password, **kwargs)
        if resultado is not None:
            if usuario is not None and (usuario.intentos_fallidos or usuario.bloqueado_hasta):
                Usuario.objects.filter(pk=usuario.pk).update(intentos_fallidos=0, bloqueado_hasta=None)
            return resultado

        if ip_hash:
            IntentoReserva.objects.create(ip_hash=ip_hash)
        if usuario is not None:
            intentos = usuario.intentos_fallidos + 1
            cambios = {"intentos_fallidos": intentos}
            if intentos >= settings.LOGIN_MAX_INTENTOS:
                cambios = {"intentos_fallidos": 0, "bloqueado_hasta": ahora + timedelta(minutes=settings.LOGIN_ESPERA_MINUTOS)}
            Usuario.objects.filter(pk=usuario.pk).update(**cambios)
        return None
