import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// Error de la API, con un mensaje que ya se le puede mostrar al doctor.
class ApiError implements Exception {
  ApiError(this.mensaje, {this.status, this.codigo});

  final String mensaje;
  final int? status;
  final String? codigo;

  bool get sinConexion => status == null;

  @override
  String toString() => mensaje;
}

/// Almacén cifrado del teléfono. Es una interfaz para poder probar la sesión sin un dispositivo.
abstract class Almacen {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

class AlmacenSeguro implements Almacen {
  const AlmacenSeguro();
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> leer(String clave) => _s.read(key: clave);
  @override
  Future<void> escribir(String clave, String valor) => _s.write(key: clave, value: valor);
  @override
  Future<void> borrar(String clave) => _s.delete(key: clave);
}

final almacenProvider = Provider<Almacen>((ref) => const AlmacenSeguro());

/// Permite reemplazar la red en las pruebas.
final adaptadorHttpProvider = Provider<HttpClientAdapter?>((ref) => null);

const claveRenovacion = 'token_renovacion';

/// Cliente de /api/v1. El interceptor renueva el token de acceso una sola vez aunque
/// varias llamadas fallen a la vez: el token de renovación es de un solo uso y reusarlo cierra la sesión.
class ApiCliente {
  /// [base] y [claveToken]: la app del cliente usa /cliente/v1 y guarda su sesión aparte de la del negocio.
  ApiCliente(this._almacen, HttpClientAdapter? adaptador, {String base = '/api/v1', this.claveToken = claveRenovacion}) {
    final opciones = BaseOptions(
      baseUrl: '$apiUrl$base',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    );
    dio = Dio(opciones);
    _dioRenovacion = Dio(opciones);
    if (adaptador != null) {
      dio.httpClientAdapter = adaptador;
      _dioRenovacion.httpClientAdapter = adaptador;
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opciones, handler) {
          if (acceso != null) opciones.headers['Authorization'] = 'Bearer $acceso';
          // Con mala señal, un reintento con la misma clave recibe la respuesta de la primera vez:
          // nunca dos citas, ni +20 por tocar dos veces +10.
          if (opciones.method != 'GET') opciones.headers.putIfAbsent('Idempotency-Key', claveIdempotencia);
          handler.next(opciones);
        },
        onError: _alFallar,
      ),
    );
  }

  final Almacen _almacen;
  final String claveToken;
  late final Dio dio;
  late final Dio _dioRenovacion;
  String? acceso;
  void Function()? alVencerSesion;
  Completer<bool>? _renovando;

  Future<void> _alFallar(DioException error, ErrorInterceptorHandler handler) async {
    final pedido = error.requestOptions;
    // Se cortó la red a mitad de un cambio: se repite una vez con la misma Idempotency-Key, así que si el
    // servidor ya lo había hecho, solo devuelve la misma respuesta.
    if (error.response == null && pedido.method != 'GET' && pedido.extra['reintentoRed'] != true) {
      pedido.extra['reintentoRed'] = true;
      try {
        return handler.resolve(await dio.fetch(pedido));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    final esAuth = error.requestOptions.path.startsWith('/auth/');
    final yaReintentada = error.requestOptions.extra['reintentada'] == true;
    if (error.response?.statusCode != 401 || esAuth || yaReintentada) {
      return handler.next(error);
    }
    if (!await renovar()) return handler.next(error);
    final opciones = error.requestOptions..extra['reintentada'] = true;
    opciones.headers['Authorization'] = 'Bearer $acceso';
    try {
      handler.resolve(await dio.fetch(opciones));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Devuelve true si hay un token de acceso nuevo.
  Future<bool> renovar() async {
    final enCurso = _renovando;
    if (enCurso != null) return enCurso.future;
    final completer = _renovando = Completer<bool>();
    var resultado = false;
    try {
      final token = await _almacen.leer(claveToken);
      if (token == null) {
        alVencerSesion?.call();
      } else {
        final r = await _dioRenovacion.post('/auth/refresh', data: {'renovacion': token});
        await guardarTokens(r.data as Map<String, dynamic>);
        resultado = true;
      }
    } on DioException catch (e) {
      // Sin señal no se cierra la sesión: la app sigue mostrando la última agenda.
      if (e.response?.statusCode == 401) {
        await _almacen.borrar(claveToken);
        acceso = null;
        alVencerSesion?.call();
      }
    } finally {
      completer.complete(resultado);
      _renovando = null;
    }
    return resultado;
  }

  Future<void> guardarTokens(Map<String, dynamic> datos) async {
    acceso = datos['acceso'] as String;
    await _almacen.escribir(claveToken, datos['renovacion'] as String);
  }

  Future<Map<String, dynamic>> get(String ruta, {Map<String, dynamic>? params}) =>
      _envolver(() => dio.get(ruta, queryParameters: params));

  Future<Map<String, dynamic>> post(String ruta, [Map<String, dynamic>? datos]) =>
      _envolver(() => dio.post(ruta, data: datos ?? {}));

  Future<Map<String, dynamic>> put(String ruta, Map<String, dynamic> datos) =>
      _envolver(() => dio.put(ruta, data: datos));

  Future<Map<String, dynamic>> delete(String ruta) => _envolver(() => dio.delete(ruta));

  Future<Map<String, dynamic>> _envolver(Future<Response<dynamic>> Function() llamada) async {
    try {
      final r = await llamada();
      return r.data is Map<String, dynamic> ? r.data as Map<String, dynamic> : <String, dynamic>{};
    } on DioException catch (e) {
      throw errorDe(e);
    }
  }

  static ApiError errorDe(DioException e) {
    final respuesta = e.response;
    if (respuesta == null) return ApiError('Sin conexión. Revisa tu internet.');
    final datos = respuesta.data;
    final detalle = datos is Map ? datos['detail'] : null;
    return ApiError(
      detalle is String ? detalle : 'Algo salió mal. Inténtalo de nuevo.',
      status: respuesta.statusCode,
      codigo: datos is Map ? datos['codigo'] as String? : null,
    );
  }
}

final _azar = Random.secure();

/// 128 bits al azar en hexadecimal: única por cada cambio que se pide.
String claveIdempotencia() => List.generate(16, (_) => _azar.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

final apiProvider = Provider<ApiCliente>((ref) {
  return ApiCliente(ref.watch(almacenProvider), ref.watch(adaptadorHttpProvider));
});

const claveRenovacionCliente = 'token_renovacion_cliente';

/// API de la app del cliente («Quiero reservar»): sus tokens no sirven en la del negocio, y viceversa.
final apiClienteProvider = Provider<ApiCliente>((ref) {
  return ApiCliente(
    ref.watch(almacenProvider),
    ref.watch(adaptadorHttpProvider),
    base: '/cliente/v1',
    claveToken: claveRenovacionCliente,
  );
});
