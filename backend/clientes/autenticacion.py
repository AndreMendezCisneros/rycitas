"""Sesión del cliente. Tokens con `tipo="cliente"`: el TokenDoctor los rechaza, así nunca entran a /api/v1.

Registro sin contraseña: correo + nombre + WhatsApp.
- VERIFICAR_CLIENTES=1 (por defecto): se manda un código de 6 dígitos al correo y la sesión se entrega al verificarlo.
- VERIFICAR_CLIENTES=0 (solo desarrollo): se confía en lo escrito. Si el correo ya existe, solo entra con el mismo
  WhatsApp.
En ambos casos el WhatsApp queda sin probar hasta abrir el enlace firmado de una cita (clientes.api.vincular).
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta
from datetime import timezone as zona

import jwt
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from ninja.security import HttpBearer

from citas.servicios import normalizar_celular
from clientes.models import Cliente, CodigoCorreo, SesionCliente
from denticita.errores import ErrorNegocio

CODIGO_MINUTOS = 10
CODIGO_INTENTOS = 5


def _hash(valor: str) -> str:
    return hashlib.sha256(valor.encode()).hexdigest()


def emitir_acceso(cliente: Cliente) -> str:
    ahora = datetime.now(zona.utc)
    return jwt.encode(
        {
            "sub": str(cliente.pk),
            "tipo": "cliente",
            "iat": ahora,
            "exp": ahora + timedelta(minutes=settings.TOKEN_ACCESO_MINUTOS),
        },
        settings.JWT_SECRET,
        algorithm="HS256",
    )


def tokens(cliente: Cliente, familia: uuid.UUID | None = None) -> dict:
    renovacion = secrets.token_urlsafe(48)
    SesionCliente.objects.create(
        cliente=cliente,
        familia=familia or uuid.uuid4(),
        token_hash=_hash(renovacion),
        expira_en=timezone.now() + timedelta(days=settings.TOKEN_RENOVACION_DIAS),
    )
    return {"acceso": emitir_acceso(cliente), "renovacion": renovacion}


def _limpiar(nombre: str, correo: str, celular: str) -> tuple[str, str, str]:
    nombre = " ".join((nombre or "").split())
    if len(nombre) < 2:
        raise ErrorNegocio("nombre_invalido", "Escribe tu nombre.", 422)
    correo = (correo or "").strip().lower()
    if "@" not in correo or "." not in correo.rsplit("@", 1)[-1] or len(correo) > 254:
        raise ErrorNegocio("correo_invalido", "Revisa tu correo.", 422)
    return nombre[:120], correo, normalizar_celular(celular)


def registrar(nombre: str, correo: str, celular: str, referido: str = "") -> dict:
    """Devuelve {"sesion": tokens, "cliente": ...} o, con verificación activa, {"verificar": True}."""
    nombre, correo, celular = _limpiar(nombre, correo, celular)
    with transaction.atomic():
        cliente = Cliente.objects.select_for_update().filter(correo=correo).first()
        nuevo = cliente is None
        if cliente is None:
            padrino = Cliente.objects.filter(codigo_referido=referido.strip().upper()).first() if referido else None
            if referido and padrino is None:
                raise ErrorNegocio("referido_invalido", "Ese código de invitación no existe.", 422)
            cliente = Cliente.objects.create(nombre=nombre, correo=correo, celular=celular, referido_por=padrino)
        elif not cliente.activo:
            raise ErrorNegocio("cuenta_inactiva", "Esta cuenta está desactivada.", 403)
        elif cliente.celular != celular and not settings.VERIFICAR_CLIENTES:
            # Sin verificación por correo, el WhatsApp hace de clave: nadie entra a una cuenta con solo el correo.
            raise ErrorNegocio(
                "datos_no_coinciden", "Ese correo ya tiene una cuenta con otro WhatsApp. Escribe el mismo número.", 409
            )

    if settings.VERIFICAR_CLIENTES:
        _enviar_codigo(cliente, nombre if nuevo else None, celular)
        return {"verificar": True, "correo": correo}
    return {"sesion": tokens(cliente), "nuevo": nuevo}


def _enviar_codigo(cliente: Cliente, nombre: str | None, celular: str) -> None:
    recientes = CodigoCorreo.objects.filter(cliente=cliente, creado_en__gte=timezone.now() - timedelta(minutes=1))
    if recientes.exists():
        raise ErrorNegocio("espera_codigo", "Ya te enviamos un código. Espera un minuto para pedir otro.", 429)
    codigo = f"{secrets.randbelow(10**6):06d}"
    # El celular nuevo (si cambió) se guarda junto al código y se aplica solo al verificar.
    CodigoCorreo.objects.create(
        cliente=cliente,
        codigo_hash=_hash(f"{codigo}:{celular}"),
        expira_en=timezone.now() + timedelta(minutes=CODIGO_MINUTOS),
    )
    send_mail(
        f"Tu código de RyCitas: {codigo}",
        f"Hola{' ' + nombre.split()[0] if nombre else ''}, tu código es {codigo}. Vence en {CODIGO_MINUTOS} minutos.\n"
        "Si no lo pediste, ignora este correo.",
        settings.DEFAULT_FROM_EMAIL,
        [cliente.correo],
    )


def verificar_codigo(correo: str, celular: str, codigo: str) -> dict:
    if not settings.VERIFICAR_CLIENTES:
        raise ErrorNegocio("no_disponible", "Esta opción no está disponible.", 404)
    correo, celular = (correo or "").strip().lower(), normalizar_celular(celular)
    invalido = ErrorNegocio("codigo_invalido", "El código no es correcto o ya venció.", 422)
    with transaction.atomic():
        pendiente = (
            CodigoCorreo.objects.select_for_update()
            .select_related("cliente")
            .filter(cliente__correo=correo, usado_en__isnull=True, expira_en__gt=timezone.now())
            .order_by("-creado_en")
            .first()
        )
        if pendiente is None or pendiente.intentos >= CODIGO_INTENTOS:
            raise invalido
        if not hmac.compare_digest(pendiente.codigo_hash, _hash(f"{codigo.strip()}:{celular}")):
            pendiente.intentos += 1
            pendiente.save(update_fields=["intentos"])
            error = True
        else:
            ahora = timezone.now()
            pendiente.usado_en = ahora
            pendiente.save(update_fields=["usado_en"])
            cliente = pendiente.cliente
            if cliente.celular != celular:
                cliente.celular, cliente.celular_verificado_en = celular, None
            cliente.correo_verificado_en = ahora
            cliente.save(update_fields=["celular", "celular_verificado_en", "correo_verificado_en"])
            error = False
    if error:
        raise invalido
    return {"sesion": tokens(cliente), "nuevo": False}


def renovar(token: str) -> dict:
    invalido = ErrorNegocio("sesion_vencida", "Tu sesión venció. Ingresa de nuevo.", 401)
    reuso = False
    with transaction.atomic():
        sesion = (
            SesionCliente.objects.select_for_update().select_related("cliente").filter(token_hash=_hash(token)).first()
        )
        if sesion is None or sesion.revocado or sesion.expira_en <= timezone.now() or not sesion.cliente.activo:
            raise invalido
        if sesion.usado_en is not None:
            SesionCliente.objects.filter(familia=sesion.familia).update(revocado=True)
            reuso = True
        else:
            sesion.usado_en = timezone.now()
            sesion.save(update_fields=["usado_en"])
            return tokens(sesion.cliente, sesion.familia)
    if reuso:
        raise invalido


def cerrar_sesion(token: str) -> None:
    sesion = SesionCliente.objects.filter(token_hash=_hash(token)).first()
    if sesion:
        SesionCliente.objects.filter(familia=sesion.familia).update(revocado=True)


class TokenCliente(HttpBearer):
    def authenticate(self, request, token):
        try:
            datos = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"], options={"require": ["exp", "sub"]})
        except jwt.PyJWTError:
            return None
        if datos.get("tipo") != "cliente":
            return None
        return Cliente.objects.filter(pk=datos["sub"], activo=True).first()
