import 'dart:convert';
import 'dart:typed_data';

import 'package:denticita_doctor/core/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Registra los enlaces que la app abre (WhatsApp, teléfono) en lugar de abrirlos.
class LanzadorFalso extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final abiertos = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    abiertos.add(url);
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

LanzadorFalso instalarLanzador() {
  final lanzador = LanzadorFalso();
  UrlLauncherPlatform.instance = lanzador;
  return lanzador;
}

class AlmacenMemoria implements Almacen {
  final datos = <String, String>{};

  @override
  Future<void> borrar(String clave) async => datos.remove(clave);
  @override
  Future<void> escribir(String clave, String valor) async => datos[clave] = valor;
  @override
  Future<String?> leer(String clave) async => datos[clave];
}

typedef Respuesta = ({int status, Object? cuerpo});

/// Reemplaza la red: responde según "MÉTODO /ruta". `null` simula que no hay señal.
class RedFalsa implements HttpClientAdapter {
  RedFalsa(this.rutas);

  final Map<String, Respuesta? Function(RequestOptions)> rutas;
  final llamadas = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final clave = '${options.method} ${options.path}';
    llamadas.add(clave);
    final manejador = rutas[clave];
    final respuesta = manejador == null ? (status: 404, cuerpo: {'detail': 'No existe $clave'}) : manejador(options);
    if (respuesta == null) {
      throw DioException.connectionError(requestOptions: options, reason: 'sin señal');
    }
    return ResponseBody.fromString(
      jsonEncode(respuesta.cuerpo),
      respuesta.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> citaJson(int id, String estado, String nombre, {String hora = '10:00', String? estimado}) => {
  'id': id,
  'estado': estado,
  'estado_texto': estado,
  'origen': 'web',
  'inicio': '2026-11-09T$hora:00-05:00',
  'fin': '2026-11-09T$hora:30-05:00',
  'inicio_estimado': estimado ?? '2026-11-09T$hora:00-05:00',
  'fin_estimado': '2026-11-09T$hora:30-05:00',
  'retraso_min': 0,
  'minutos_extra': 0,
  'inicio_real': null,
  'fin_real': null,
  'tratamiento': {'id': 1, 'nombre': 'Limpieza'},
  'paciente': {'id': id, 'nombre': nombre, 'celular': '+51987654321', 'inasistencias': 0},
};

Map<String, dynamic> agendaJson(List<Map<String, dynamic>> citas, {int retraso = 0, int porAprobar = 0}) => {
  'fecha': '2026-11-09',
  'retraso_min': retraso,
  'por_aprobar': porAprobar,
  'citas': citas,
  'huecos': [
    {'inicio': '2026-11-09T12:00:00-05:00', 'fin': '2026-11-09T13:00:00-05:00'},
  ],
  'generado_en': '2026-11-09T08:00:00-05:00',
};
