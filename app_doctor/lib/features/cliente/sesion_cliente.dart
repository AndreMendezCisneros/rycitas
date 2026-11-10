import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../auth/sesion.dart' show EstadoSesion;

/// Resultado del registro: entró directo o (con la verificación por correo activa) falta el código.
enum ResultadoRegistro { adentro, faltaCodigo }

class SesionCliente extends Notifier<EstadoSesion> {
  @override
  EstadoSesion build() {
    final api = ref.watch(apiClienteProvider);
    api.alVencerSesion = () => state = EstadoSesion.cerrada;
    Future.microtask(_restaurar);
    return EstadoSesion.cargando;
  }

  Future<void> _restaurar() async {
    if (await ref.read(almacenProvider).leer(claveRenovacionCliente) == null) {
      state = EstadoSesion.cerrada;
      return;
    }
    await ref.read(apiClienteProvider).renovar();
    if (state == EstadoSesion.cargando) state = EstadoSesion.activa;
  }

  /// Lanza [ApiError] con el mensaje para mostrar.
  Future<ResultadoRegistro> registrar({
    required String nombre,
    required String correo,
    required String celular,
    String referido = '',
  }) async {
    final api = ref.read(apiClienteProvider);
    final datos = await api.post('/auth/registro', {
      'nombre': nombre.trim(),
      'correo': correo.trim(),
      'celular': celular.trim(),
      'referido': referido.trim(),
      'acepta_politica': true,
    });
    if (datos['verificar'] == true) return ResultadoRegistro.faltaCodigo;
    await api.guardarTokens(datos);
    state = EstadoSesion.activa;
    return ResultadoRegistro.adentro;
  }

  Future<void> verificar({required String correo, required String celular, required String codigo}) async {
    final api = ref.read(apiClienteProvider);
    final datos = await api.post('/auth/verificar', {
      'correo': correo.trim(),
      'celular': celular.trim(),
      'codigo': codigo.trim(),
    });
    await api.guardarTokens(datos);
    state = EstadoSesion.activa;
  }

  Future<void> cerrar() async {
    final api = ref.read(apiClienteProvider);
    final almacen = ref.read(almacenProvider);
    final token = await almacen.leer(claveRenovacionCliente);
    if (token != null) {
      try {
        await api.dio.post('/auth/logout', data: {'renovacion': token});
      } on DioException {
        // Sin señal igual se cierra en el teléfono.
      }
    }
    await almacen.borrar(claveRenovacionCliente);
    api.acceso = null;
    state = EstadoSesion.cerrada;
  }
}

final sesionClienteProvider = NotifierProvider<SesionCliente, EstadoSesion>(SesionCliente.new);
