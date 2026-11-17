"""Sesión del cliente. Tokens con `tipo="cliente"`: el TokenDoctor los rechaza, así nunca entran a /api/v1.

Dos caminos: «Crear cuenta» (nombre, correo, WhatsApp y contraseña) y «Entrar» (correo y contraseña).
- VERIFICAR_CLIENTES=1 (por defecto): al crear la cuenta se manda un código de 6 dígitos al correo y la sesión se
  entrega al verificarlo.
- VERIFICAR_CLIENTES=0: el correo no se comprueba.
Las cuentas de antes de las contraseñas crean la suya en «Crear cuenta» con su mismo correo y WhatsApp.
La contraseña protege la cuenta, pero no prueba que el WhatsApp sea suyo: eso sigue siendo el enlace firmado de una
cita (clientes.api.vincular). Hasta entonces la cuenta ve solo lo que reservó desde la app.
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
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from ninja.security import HttpBearer

from citas.servicios import normalizar_celular
from clientes.models import Cliente, CodigoCorreo, SesionCliente
from denticita.errores import ErrorNegocio

CODIGO_MINUTOS = 10
CODIGO_INTENTOS = 5
CLAVE_MINIMO = 8


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


def _validar_clave(clave: str) -> str:
    if len(clave or "") < CLAVE_MINIMO:
        raise ErrorNegocio("clave_corta", f"La contraseña debe tener al menos {CLAVE_MINIMO} caracteres.", 422)
    if len(clave) > 128:
        raise ErrorNegocio("clave_larga", "La contraseña es demasiado larga.", 422)
    return make_password(clave)


def registrar(
    nombre: str, correo: str, celular: str, clave: str, referido: str = "", acepta_publicidad: bool = False
) -> dict:
    """Crea la cuenta. Devuelve {"sesion": tokens, "nuevo": ...} o, con verificación activa, {"verificar": True}."""
    nombre, correo, celular = _limpiar(nombre, correo, celular)
    hash_clave = _validar_clave(clave)
    clave_nueva = ""
    with transaction.atomic():
        cliente = Cliente.objects.select_for_update().filter(correo=correo).first()
        nuevo = cliente is None
        if cliente is None:
            padrino = Cliente.objects.filter(codigo_referido=referido.strip().upper()).first() if referido else None
            if referido and padrino is None:
                raise ErrorNegocio("referido_invalido", "Ese código de invitación no existe.", 422)
            ahora = timezone.now()
            cliente = Cliente.objects.create(
                nombre=nombre,
                correo=correo,
                celular=celular,
                clave=hash_clave,
                referido_por=padrino,
                consentimiento_en=ahora,
                politica_version=settings.POLITICA_VERSION,
                acepta_publicidad_en=ahora if acepta_publicidad else None,
            )
        elif not cliente.activo:
            raise ErrorNegocio("cuenta_inactiva", "Esta cuenta está desactivada.", 403)
        elif cliente.clave and (cliente.correo_verificado_en or not settings.VERIFICAR_CLIENTES):
            raise ErrorNegocio("cuenta_existe", "Ya tienes una cuenta con ese correo. Entra con tu contraseña.", 409)
        elif settings.VERIFICAR_CLIENTES:
            # Cuenta antigua o sin confirmar: la contraseña se aplica recién al verificar el código del correo.
            clave_nueva = hash_clave
        elif cliente.celular != celular:
            # Sin verificación por correo, el WhatsApp de siempre prueba que la cuenta antigua es suya.
            raise ErrorNegocio(
                "datos_no_coinciden", "Ese correo ya tiene una cuenta con otro WhatsApp. Escribe el mismo número.", 409
            )
        else:
            cliente.clave = hash_clave
            cliente.save(update_fields=["clave"])

    if settings.VERIFICAR_CLIENTES:
        _enviar_codigo(cliente, nombre if nuevo else None, celular, clave_nueva)
        return {"verificar": True, "correo": correo}
    return {"sesion": tokens(cliente), "nuevo": nuevo}


# Hash de relleno: si el correo no existe se compara igual, así el tiempo de respuesta no revela qué cuentas hay.
_CLAVE_FALSA = make_password("relleno-para-tiempo-constante")


def entrar(correo: str, clave: str) -> dict:
    correo = (correo or "").strip().lower()
    cliente = Cliente.objects.filter(correo=correo).first()
    ok = check_password(clave or "", cliente.clave if cliente and cliente.clave else _CLAVE_FALSA)
    if cliente is not None and not cliente.clave:
        raise ErrorNegocio(
            "sin_clave",
            "Tu cuenta todavía no tiene contraseña. Créala en «Crear cuenta» con tu mismo correo y WhatsApp.",
            409,
        )
    if cliente is None or not ok:
        raise ErrorNegocio("credenciales", "Correo o contraseña incorrectos.", 401)
    if not cliente.activo:
        raise ErrorNegocio("cuenta_inactiva", "Esta cuenta está desactivada.", 403)
    if settings.VERIFICAR_CLIENTES and cliente.correo_verificado_en is None:
        raise ErrorNegocio(
            "correo_sin_confirmar", "Confirma tu correo: vuelve a «Crear cuenta» para recibir el código.", 403
        )
    return {"sesion": tokens(cliente)}


def cambiar_clave(cliente: Cliente, actual: str, nueva: str) -> None:
    if cliente.clave and not check_password(actual or "", cliente.clave):
        raise ErrorNegocio("clave_actual", "Tu contraseña actual no es correcta.", 422)
    cliente.clave = _validar_clave(nueva)
    cliente.save(update_fields=["clave"])


def _enviar_codigo(cliente: Cliente, nombre: str | None, celular: str, clave_nueva: str = "") -> None:
    recientes = CodigoCorreo.objects.filter(cliente=cliente, creado_en__gte=timezone.now() - timedelta(minutes=1))
    if recientes.exists():
        raise ErrorNegocio("espera_codigo", "Ya te enviamos un código. Espera un minuto para pedir otro.", 429)
    codigo = f"{secrets.randbelow(10**6):06d}"
    # El celular nuevo (si cambió) se guarda junto al código y se aplica solo al verificar.
    CodigoCorreo.objects.create(
        cliente=cliente,
        codigo_hash=_hash(f"{codigo}:{celular}"),
        clave_nueva=clave_nueva,
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
            if pendiente.clave_nueva:
                cliente.clave = pendiente.clave_nueva
            cliente.save(update_fields=["celular", "celular_verificado_en", "correo_verificado_en", "clave"])
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


def cerrar_sesion(token: str, token_fcm: str = "") -> None:
    """Revoca la sesión y deja de mandar avisos a ese teléfono (SEG-07)."""
    from clientes.models import DispositivoCliente

    sesion = SesionCliente.objects.filter(token_hash=_hash(token)).first()
    if sesion:
        SesionCliente.objects.filter(familia=sesion.familia).update(revocado=True)
        if token_fcm:
            DispositivoCliente.objects.filter(cliente_id=sesion.cliente_id, token_fcm=token_fcm).delete()


class TokenCliente(HttpBearer):
    def authenticate(self, request, token):
        try:
            datos = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"], options={"require": ["exp", "sub"]})
        except jwt.PyJWTError:
            return None
        if datos.get("tipo") != "cliente":
            return None
        return Cliente.objects.filter(pk=datos["sub"], activo=True).first()
