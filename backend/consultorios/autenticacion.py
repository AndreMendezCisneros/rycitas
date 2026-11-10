"""Sesión del doctor: token de acceso de 15 min y de renovación de 30 días rotativo (RF-20, RNF-07)."""
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta
from datetime import timezone as zona

import jwt
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from ninja.security import HttpBearer

from consultorios.models import SesionRenovacion, Usuario
from denticita.errores import ErrorNegocio


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def emitir_acceso(usuario: Usuario) -> str:
    ahora = datetime.now(zona.utc)
    return jwt.encode(
        {
            "sub": str(usuario.pk),
            "tipo": "acceso",
            "iat": ahora,
            "exp": ahora + timedelta(minutes=settings.TOKEN_ACCESO_MINUTOS),
        },
        settings.JWT_SECRET,
        algorithm="HS256",
    )


def emitir_renovacion(usuario: Usuario, familia: uuid.UUID | None = None) -> str:
    token = secrets.token_urlsafe(48)
    SesionRenovacion.objects.create(
        usuario=usuario,
        familia=familia or uuid.uuid4(),
        token_hash=_hash(token),
        expira_en=timezone.now() + timedelta(days=settings.TOKEN_RENOVACION_DIAS),
    )
    return token


def tokens(usuario: Usuario, familia: uuid.UUID | None = None) -> dict:
    return {"acceso": emitir_acceso(usuario), "renovacion": emitir_renovacion(usuario, familia)}


CREDENCIALES_INVALIDAS = ErrorNegocio("credenciales_invalidas", "Correo o contraseña incorrectos.", 401)


def iniciar_sesion(correo: str, password: str) -> Usuario:
    """Tras 5 intentos fallidos la cuenta espera 15 min, incluso con la contraseña correcta."""
    ahora = timezone.now()
    with transaction.atomic():
        usuario = Usuario.objects.select_for_update().filter(correo__iexact=correo.strip()).first()
        if usuario is None or usuario.consultorio_id is None or not usuario.activo:
            # Mismo costo que una verificación real para no revelar qué correos existen.
            Usuario().set_password(password)
            raise CREDENCIALES_INVALIDAS
        if usuario.bloqueado_hasta and usuario.bloqueado_hasta > ahora:
            minutos = int((usuario.bloqueado_hasta - ahora).total_seconds() // 60) + 1
            raise ErrorNegocio("cuenta_en_espera", f"Demasiados intentos. Vuelve a intentar en {minutos} min.", 429)
        if not usuario.check_password(password):
            usuario.intentos_fallidos += 1
            if usuario.intentos_fallidos >= settings.LOGIN_MAX_INTENTOS:
                usuario.bloqueado_hasta = ahora + timedelta(minutes=settings.LOGIN_ESPERA_MINUTOS)
                usuario.intentos_fallidos = 0
            usuario.save(update_fields=["intentos_fallidos", "bloqueado_hasta"])
            error = True
        else:
            usuario.intentos_fallidos = 0
            usuario.bloqueado_hasta = None
            usuario.last_login = ahora
            usuario.save(update_fields=["intentos_fallidos", "bloqueado_hasta", "last_login"])
            error = False
    if error:  # fuera del atomic para que el contador sí quede guardado
        raise CREDENCIALES_INVALIDAS
    return usuario


def renovar(token: str) -> dict:
    ahora = timezone.now()
    invalido = ErrorNegocio("sesion_vencida", "Tu sesión venció. Ingresa de nuevo.", 401)
    reuso = False
    with transaction.atomic():
        sesion = (
            SesionRenovacion.objects.select_for_update()
            .select_related("usuario")
            .filter(token_hash=_hash(token))
            .first()
        )
        if sesion is None or sesion.revocado or sesion.expira_en <= ahora or not sesion.usuario.activo:
            raise invalido
        if sesion.usado_en is not None:
            SesionRenovacion.objects.filter(familia=sesion.familia).update(revocado=True)
            reuso = True
        else:
            sesion.usado_en = ahora
            sesion.save(update_fields=["usado_en"])
            return tokens(sesion.usuario, sesion.familia)
    if reuso:
        raise invalido


def cerrar_sesion(token: str) -> None:
    sesion = SesionRenovacion.objects.filter(token_hash=_hash(token)).first()
    if sesion:
        SesionRenovacion.objects.filter(familia=sesion.familia).update(revocado=True)


class TokenDoctor(HttpBearer):
    """Deja en `request.auth` al usuario; de ahí sale el consultorio de toda consulta (RNF-08)."""

    def authenticate(self, request, token):
        try:
            datos = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"], options={"require": ["exp", "sub"]})
        except jwt.PyJWTError:
            return None
        if datos.get("tipo") != "acceso":
            return None
        usuario = Usuario.objects.select_related("consultorio").filter(pk=datos["sub"], activo=True).first()
        if usuario is None or usuario.consultorio_id is None:
            return None
        return usuario
