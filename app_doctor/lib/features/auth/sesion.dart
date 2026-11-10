import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/push.dart';

enum EstadoSesion { cargando, activa, cerrada }

const _claveCorreo = 'correo';
const claveAgendaGuardada = 'agenda_guardada';

class Sesion extends Notifier<EstadoSesion> {
  String? correo;

  @override
  EstadoSesion build() {
    final api = ref.watch(apiProvider);
    api.alVencerSesion = () => state = EstadoSesion.cerrada;
    Future.microtask(_restaurar);
    return EstadoSesion.cargando;
  }

  Future<void> _restaurar() async {
    final almacen = ref.read(almacenProvider);
    correo = await almacen.leer(_claveCorreo);
    if (await almacen.leer(claveRenovacion) == null) {
      state = EstadoSesion.cerrada;
      return;
    }
    // Si no hay señal, renovar() no cierra la sesión: se entra y se ve la última agenda guardada.
    await ref.read(apiProvider).renovar();
    if (state == EstadoSesion.cargando) state = EstadoSesion.activa;
  }

  /// Lanza [ApiError] si no se pudo entrar.
  Future<void> iniciar(String correoIngresado, String password) async {
    final api = ref.read(apiProvider);
    final datos = await api.post('/auth/login', {'correo': correoIngresado.trim(), 'password': password});
    await api.guardarTokens(datos);
    correo = correoIngresado.trim();
    await ref.read(almacenProvider).escribir(_claveCorreo, correo!);
    state = EstadoSesion.activa;
  }

  Future<void> cerrar() async {
    final api = ref.read(apiProvider);
    final almacen = ref.read(almacenProvider);
    final token = await almacen.leer(claveRenovacion);
    if (token != null) {
      try {
        // Con el token del teléfono, el servidor deja de mandarle avisos (un celular prestado no los sigue viendo).
        await api.dio.post('/auth/logout', data: {'renovacion': token, 'token_fcm': Push.ultimoToken ?? ''});
      } on DioException {
        // Sin señal igual se cierra en el teléfono; el token vence solo.
      }
    }
    await almacen.borrar(claveRenovacion);
    await almacen.borrar(claveAgendaGuardada); // datos de pacientes: no quedan en el teléfono
    await almacen.borrar('negocio_guardado');
    await almacen.borrar('bloqueo_activo');
    api.acceso = null;
    state = EstadoSesion.cerrada;
  }
}

final sesionProvider = NotifierProvider<Sesion, EstadoSesion>(Sesion.new);
