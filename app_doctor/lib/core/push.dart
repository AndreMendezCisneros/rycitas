import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// Un canal por tipo de aviso, cada uno con su sonido con voz (android/app/src/main/res/raw/`aviso_<canal>.wav`):
/// el profesional sabe qué pasó sin mirar el teléfono. Deben coincidir con `CANAL_POR_TIPO` en mensajeria/push.py.
/// Android fija el sonido al crear el canal; para cambiar un sonido hay que usar un id de canal nuevo.
AndroidNotificationChannel _nuevoCanal(String id, String nombre, String descripcion) => AndroidNotificationChannel(
  id,
  nombre,
  description: descripcion,
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('aviso_$id'),
);

final canalesDeAviso = [
  _nuevoCanal('reservas_v2', 'Reservas por confirmar', '«¡Hola! Tienes una nueva reserva por confirmar»'),
  _nuevoCanal('nuevas_v2', 'Citas nuevas', '«¡Listo! Se agendó una nueva cita»'),
  _nuevoCanal('proximas_v2', 'Cita por empezar', '«Tu próxima cita empieza en unos minutos»'),
  _nuevoCanal('general_v2', 'Resumen y otros avisos', 'Agenda de mañana y otros avisos'),
];

String canalDeAviso(String? tipo) => switch (tipo) {
  'por_aprobar' => 'reservas_v2',
  'nueva_cita' => 'nuevas_v2',
  'cita_proxima' => 'proximas_v2',
  _ => 'general_v2',
};

/// Push del doctor (RF-31, RF-32). Si el proyecto aún no tiene Firebase configurado, la app funciona
/// igual y se actualiza consultando cada 30 s.
class Push {
  Push(this._api, this._alRecibir, this._alAbrir);

  final ApiCliente _api;
  final void Function() _alRecibir;

  /// Al tocar la notificación: lleva a la pantalla que corresponde a sus datos (tipo, negocio…).
  final void Function(Map<String, dynamic> datos) _alAbrir;

  /// El token del teléfono es uno solo: si se cambia de modo (negocio ↔ cliente), se registra en la otra API.
  static String? ultimoToken;
  final _locales = FlutterLocalNotificationsPlugin();
  final _suscripciones = <StreamSubscription<dynamic>>[];
  bool _listo = false;

  Future<void> iniciar() async {
    if (kIsWeb || _listo) return;
    if (ultimoToken != null) unawaited(_registrar(ultimoToken!));
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('Push desactivado: Firebase sin configurar ($error)');
      return;
    }
    _listo = true;

    await _locales.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    final android = _locales.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final canal in canalesDeAviso) {
      await android?.createNotificationChannel(canal);
    }
    // Canales de versiones anteriores (sin voz y con la voz robótica): ya no se usan.
    for (final viejo in ['citas', 'reservas', 'nuevas', 'proximas', 'general']) {
      await android?.deleteNotificationChannel(channelId: viejo);
    }

    final mensajeria = FirebaseMessaging.instance;
    await mensajeria.requestPermission();

    // onRegistered entrega el token inicial y cada renovación; hay que escuchar antes de register().
    _suscripciones
      ..add(mensajeria.onRegistered.listen(_registrar))
      // Con la app abierta Android no muestra el aviso por sí solo.
      ..add(FirebaseMessaging.onMessage.listen(_mostrar))
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) {
          _alRecibir();
          _alAbrir(m.data);
        }),
      );
    try {
      await mensajeria.register();
    } catch (error) {
      // Sin token no hay push, pero la app sigue funcionando (se refresca cada 30 s).
      debugPrint('Push sin registrar: $error');
    }
    final inicial = await mensajeria.getInitialMessage();
    if (inicial != null) _alAbrir(inicial.data);
  }

  Future<void> _registrar(String token) async {
    ultimoToken = token;
    try {
      await _api.post('/dispositivos', {'token_fcm': token, 'plataforma': 'android'});
    } on ApiError catch (error) {
      debugPrint('No se pudo registrar el dispositivo: $error');
    }
  }

  void _mostrar(RemoteMessage mensaje) {
    _alRecibir();
    final aviso = mensaje.notification;
    if (aviso == null) return;
    final id = canalDeAviso(mensaje.data['tipo'] as String?);
    final canal = canalesDeAviso.firstWhere((c) => c.id == id);
    _locales.show(
      id: mensaje.hashCode,
      title: aviso.title,
      body: aviso.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: canal.sound,
        ),
      ),
    );
  }

  void detener() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    _suscripciones.clear();
    _listo = false; // al volver a este modo se escucha de nuevo
  }
}

/// Se incrementa con cada push; la agenda lo observa para refrescarse.
final avisoPushProvider = StateProvider<int>((ref) => 0);

/// Ruta a la que hay que ir porque el doctor tocó una notificación.
final destinoPushProvider = StateProvider<String?>((ref) => null);

String? rutaDeAviso(String? tipo) => switch (tipo) {
  'recordatorios' || 'resumen' => '/recordatorios',
  'por_aprobar' => '/por-aprobar',
  // «En 30 min: Rosa Paz» y las citas nuevas: a la agenda del día.
  'cita_proxima' || 'nueva_cita' => '/',
  _ => null,
};

final pushProvider = Provider<Push>((ref) {
  final push = Push(
    ref.watch(apiProvider),
    () => ref.read(avisoPushProvider.notifier).state++,
    (datos) => ref.read(destinoPushProvider.notifier).state = rutaDeAviso(datos['tipo'] as String?),
  );
  ref.onDispose(push.detener);
  return push;
});

/// Avisos de la app del cliente: sellos, tarjeta llena y promociones de sus lugares.
String rutaDeAvisoCliente(Map<String, dynamic> datos) => switch (datos['tipo']) {
  'campana' || 'sello' || 'tarjeta_llena' when datos['negocio'] != null => '/cliente/negocio/${datos['negocio']}',
  _ => '/cliente/beneficios',
};

final pushClienteProvider = Provider<Push>((ref) {
  final push = Push(
    ref.watch(apiClienteProvider),
    () {},
    (datos) => ref.read(destinoPushProvider.notifier).state = rutaDeAvisoCliente(datos),
  );
  ref.onDispose(push.detener);
  return push;
});
