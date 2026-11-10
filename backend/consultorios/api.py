from ninja import Router, Schema

from consultorios import autenticacion
from consultorios.models import Dispositivo

router = Router(tags=["sesión"])


class LoginEntrada(Schema):
    correo: str
    password: str


class TokenEntrada(Schema):
    renovacion: str


class SalidaEntrada(Schema):
    renovacion: str
    token_fcm: str = ""  # el teléfono deja de recibir avisos


class DispositivoEntrada(Schema):
    token_fcm: str
    plataforma: str = "android"


@router.post("/login")
def login(request, datos: LoginEntrada):
    usuario = autenticacion.iniciar_sesion(datos.correo, datos.password)
    return {
        **autenticacion.tokens(usuario),
        "usuario": {"correo": usuario.correo, "consultorio": usuario.consultorio.nombre},
    }


@router.post("/refresh")
def refresh(request, datos: TokenEntrada):
    return autenticacion.renovar(datos.renovacion)


@router.post("/logout", response={204: None})
def logout(request, datos: SalidaEntrada):
    autenticacion.cerrar_sesion(datos.renovacion, datos.token_fcm)
    return 204, None


router_dispositivos = Router(tags=["sesión"])


@router_dispositivos.post("/auth/cerrar-todas")
def cerrar_todas(request):
    """Mejora 7: si pierdes el celular, cierras la app en todos los equipos desde otro. Este también deberá volver
    a entrar cuando venza su token de acceso."""
    from consultorios.models import SesionRenovacion

    cerradas = SesionRenovacion.objects.filter(usuario=request.auth, revocado=False).update(revocado=True)
    Dispositivo.objects.filter(usuario=request.auth).delete()
    return {"sesiones_cerradas": cerradas}


@router_dispositivos.post("/dispositivos", response={204: None})
def registrar_dispositivo(request, datos: DispositivoEntrada):
    Dispositivo.objects.update_or_create(
        token_fcm=datos.token_fcm, defaults={"usuario": request.auth, "plataforma": datos.plataforma}
    )
    return 204, None
