"""Cabecera Idempotency-Key (análisis RYJEC, mejora 1).

Con mala señal la app o el navegador reintentan: sin esto, un reintento de «Reservar» crea dos citas y un doble
toque en «+10» suma 20. Con la misma clave, la segunda petición recibe la respuesta guardada de la primera.
"""
from __future__ import annotations

import hashlib
import json
from datetime import timedelta
from functools import wraps

from django.conf import settings
from django.db import IntegrityError, transaction
from django.http import HttpResponseBase
from django.utils import timezone
from ninja import Status

from denticita.errores import ErrorNegocio

VIGENCIA = timedelta(hours=24)


def _alcance(request) -> str:
    usuario = getattr(request, "auth", None)
    if usuario is not None and getattr(usuario, "pk", None):
        # «u» cuenta del negocio, «c» cliente de la app: el mismo id en dos tablas no debe compartir claves.
        return f"{'c' if usuario.__class__.__name__ == 'Cliente' else 'u'}{usuario.pk}"
    from sitio.red import ip_cliente

    return "ip" + hashlib.sha256(f"{settings.SECRET_KEY}{ip_cliente(request)}".encode()).hexdigest()[:40]


def _huella(request) -> str:
    return hashlib.sha256(request.method.encode() + request.path.encode() + (request.body or b"")).hexdigest()


def idempotente(vista):
    @wraps(vista)
    def envoltura(request, *args, **kwargs):
        from citas.models import ClaveIdempotencia

        clave = (request.headers.get("Idempotency-Key") or "").strip()
        if not clave:
            return vista(request, *args, **kwargs)
        if len(clave) > 80:
            raise ErrorNegocio("clave_invalida", "Idempotency-Key admite hasta 80 caracteres.", 422)
        alcance, huella = _alcance(request), _huella(request)
        ClaveIdempotencia.objects.filter(creado_en__lt=timezone.now() - VIGENCIA, alcance=alcance).delete()
        try:
            with transaction.atomic():
                registro = ClaveIdempotencia.objects.create(alcance=alcance, clave=clave, huella=huella)
        except IntegrityError:
            previo = ClaveIdempotencia.objects.get(alcance=alcance, clave=clave)
            if previo.huella != huella:
                raise ErrorNegocio("clave_reutilizada", "Esa Idempotency-Key ya se usó con otra petición.", 422)
            if previo.estado == 0:
                raise ErrorNegocio("en_proceso", "Tu pedido anterior aún se está procesando.", 409)
            # Sin código propio, Ninja vuelve a elegir el mismo estado que en la primera respuesta.
            return previo.respuesta if previo.estado == 200 else Status(previo.estado, previo.respuesta)
        try:
            resultado = vista(request, *args, **kwargs)
        except Exception:
            registro.delete()  # un error deja reintentar con la misma clave
            raise
        if isinstance(resultado, HttpResponseBase):
            registro.delete()  # respuestas de archivo o redirección no se guardan
            return resultado
        if isinstance(resultado, Status):
            estado, cuerpo = resultado.status_code, resultado.value
        elif isinstance(resultado, tuple) and len(resultado) == 2:
            estado, cuerpo = resultado
        else:
            estado, cuerpo = 200, resultado
        if hasattr(cuerpo, "model_dump"):
            cuerpo = cuerpo.model_dump(mode="json")
        registro.estado = estado
        registro.respuesta = json.loads(json.dumps(cuerpo, default=str))
        registro.save(update_fields=["estado", "respuesta"])
        return resultado

    return envoltura
