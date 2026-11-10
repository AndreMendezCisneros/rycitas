import 'dart:async';
import 'dart:convert';

import 'package:denticita_doctor/core/api.dart';
import 'package:denticita_doctor/core/fechas.dart';
import 'package:denticita_doctor/core/modo.dart';
import 'package:denticita_doctor/features/agenda/agenda_controlador.dart';
import 'package:denticita_doctor/features/auth/sesion.dart';
import 'package:denticita_doctor/main.dart';
import 'package:denticita_doctor/shared/modelos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_10y.dart' as zonas;
import 'package:timezone/timezone.dart' as tz;

import 'apoyo.dart';

Respuesta ok(Object cuerpo) => (status: 200, cuerpo: cuerpo);

const tokens = {'acceso': 'a2', 'renovacion': 'r2'};

Widget app(RedFalsa red, AlmacenMemoria almacen) => ProviderScope(
  overrides: [almacenProvider.overrideWithValue(almacen), adaptadorHttpProvider.overrideWithValue(red)],
  child: const RyCitasApp(),
);

ProviderContainer contenedor(RedFalsa red, AlmacenMemoria almacen) {
  final c = ProviderContainer(
    overrides: [almacenProvider.overrideWithValue(almacen), adaptadorHttpProvider.overrideWithValue(red)],
  );
  addTearDown(c.dispose);
  return c;
}

/// Fija la hora de Lima durante una prueba (por ejemplo, para pasar la tolerancia de «No vino»).
void fijarReloj(int hora, int minuto, {int dia = 9}) {
  Fechas.reloj = () => tz.TZDateTime(Fechas.lima, 2026, 11, dia, hora, minuto);
  addTearDown(() => Fechas.reloj = Fechas.relojReal);
}

Future<void> esperarSesion(ProviderContainer c) async {
  c.read(sesionProvider);
  for (var i = 0; i < 20 && c.read(sesionProvider) == EstadoSesion.cargando; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    zonas.initializeTimeZones();
    await initializeDateFormatting('es');
  });

  group('modelos', () {
    test('lee la agenda del JSON real de la API', () {
      final agenda = Agenda.fromJson(agendaJson([citaJson(1, 'programada', 'Rosa')], retraso: 5));
      expect(agenda.retrasoMin, 5);
      expect(agenda.citas.single.paciente.nombre, 'Rosa');
      expect(agenda.citas.single.programada, isTrue);
      expect(agenda.huecos.single.fin, contains('13:00'));
    });
  });

  group('fechas', () {
    test('muestra la hora de Lima venga como venga el instante', () {
      expect(Fechas.hora('2026-11-09T15:00:00Z'), '10:00');
      expect(Fechas.hora('2026-11-09T10:00:00-05:00'), '10:00');
    });

    test('arma el instante de la API en hora de Lima', () {
      final instante = Fechas.instanteApi(DateTime(2026, 11, 9), const TimeOfDay(hour: 9, minute: 30));
      expect(DateTime.parse(instante).toUtc(), DateTime.utc(2026, 11, 9, 14, 30));
    });

    test('el día de una fecha no se corre por la zona horaria', () {
      expect(Fechas.diaLargo('2026-11-09'), 'lunes 9 de noviembre');
    });
  });

  group('sesión', () {
    test('sin token guardado pide iniciar sesión', () async {
      final c = contenedor(RedFalsa({}), AlmacenMemoria());
      await esperarSesion(c);
      expect(c.read(sesionProvider), EstadoSesion.cerrada);
    });

    test('con token vigente entra y lo rota', () async {
      final almacen = AlmacenMemoria()..datos[claveRenovacion] = 'r1';
      final c = contenedor(RedFalsa({'POST /auth/refresh': (_) => ok(tokens)}), almacen);
      await esperarSesion(c);
      expect(c.read(sesionProvider), EstadoSesion.activa);
      expect(almacen.datos[claveRenovacion], 'r2');
    });

    test('token rechazado cierra la sesión y lo borra', () async {
      final almacen = AlmacenMemoria()..datos[claveRenovacion] = 'r1';
      final c = contenedor(
        RedFalsa({
          'POST /auth/refresh': (_) => (status: 401, cuerpo: {'detail': 'venció'}),
        }),
        almacen,
      );
      await esperarSesion(c);
      expect(c.read(sesionProvider), EstadoSesion.cerrada);
      expect(almacen.datos.containsKey(claveRenovacion), isFalse);
    });

    test('sin señal no cierra la sesión ni borra el token', () async {
      final almacen = AlmacenMemoria()..datos[claveRenovacion] = 'r1';
      final c = contenedor(RedFalsa({'POST /auth/refresh': (_) => null}), almacen);
      await esperarSesion(c);
      expect(c.read(sesionProvider), EstadoSesion.activa);
      expect(almacen.datos[claveRenovacion], 'r1');
    });

    test('cerrar sesión borra el token y la agenda guardada', () async {
      final almacen = AlmacenMemoria()
        ..datos[claveRenovacion] = 'r1'
        ..datos[claveAgendaGuardada] = '{}';
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'POST /auth/logout': (_) => (status: 204, cuerpo: null),
      });
      final c = contenedor(red, almacen);
      await esperarSesion(c);
      await c.read(sesionProvider.notifier).cerrar();
      expect(c.read(sesionProvider), EstadoSesion.cerrada);
      expect(almacen.datos, isEmpty);
    });
  });

  group('renovación del token', () {
    test('un 401 renueva y reintenta la llamada original', () async {
      final almacen = AlmacenMemoria()..datos[claveRenovacion] = 'r1';
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (o) =>
            o.headers['Authorization'] == 'Bearer a2' ? ok({'ok': true}) : (status: 401, cuerpo: {'detail': 'vencido'}),
      });
      final api = ApiCliente(almacen, red);
      expect(await api.get('/agenda'), {'ok': true});
      expect(red.llamadas.where((l) => l == 'POST /auth/refresh'), hasLength(1));
    });

    test('varias llamadas con 401 a la vez renuevan una sola vez', () async {
      final almacen = AlmacenMemoria()..datos[claveRenovacion] = 'r1';
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /a': (o) => o.headers['Authorization'] == 'Bearer a2' ? ok({}) : (status: 401, cuerpo: {}),
        'GET /b': (o) => o.headers['Authorization'] == 'Bearer a2' ? ok({}) : (status: 401, cuerpo: {}),
        'GET /c': (o) => o.headers['Authorization'] == 'Bearer a2' ? ok({}) : (status: 401, cuerpo: {}),
      });
      final api = ApiCliente(almacen, red);
      await Future.wait([api.get('/a'), api.get('/b'), api.get('/c')]);
      expect(red.llamadas.where((l) => l == 'POST /auth/refresh'), hasLength(1));
    });

    test('el error de la API llega con su mensaje y su código', () async {
      final red = RedFalsa({
        'POST /citas': (_) => (status: 409, cuerpo: {'detail': 'Ya fue tomado', 'codigo': 'horario_tomado'}),
      });
      expect(
        () => ApiCliente(AlmacenMemoria(), red).post('/citas'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.mensaje, 'mensaje', 'Ya fue tomado')
              .having((e) => e.codigo, 'codigo', 'horario_tomado'),
        ),
      );
    });

    test('sin señal da un error reconocible', () async {
      final red = RedFalsa({'GET /agenda': (_) => null});
      expect(
        () => ApiCliente(AlmacenMemoria(), red).get('/agenda'),
        throwsA(isA<ApiError>().having((e) => e.sinConexion, 'sinConexion', isTrue)),
      );
    });
  });

  group('agenda', () {
    late AlmacenMemoria almacen;

    setUp(() => almacen = AlmacenMemoria()..datos[claveRenovacion] = 'r1');

    Future<ProviderContainer> listo(RedFalsa red) async {
      final c = contenedor(red, almacen);
      c.listen(agendaProvider, (_, _) {});
      await esperarSesion(c);
      await c.read(agendaProvider.future);
      return c;
    }

    test('la acción se ve al instante y luego toma lo que calculó el servidor', () async {
      final respuesta = Completer<void>();
      final recalculada = agendaJson([
        citaJson(1, 'en_curso', 'Rosa'),
        citaJson(2, 'programada', 'Luis', hora: '11:00', estimado: '2026-11-09T11:20:00-05:00'),
      ]);
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'programada', 'Rosa')])),
        'POST /citas/1/iniciar': (_) => ok({'agenda': recalculada}),
      });
      final c = await listo(red);
      final enVuelo = c.read(agendaProvider.notifier).accion(AccionConsulta.iniciar, 1);
      expect(c.read(agendaProvider).value!.agenda.citas.single.estado, 'en_curso'); // sin esperar a la red
      respuesta.complete();
      expect(await enVuelo, isNull);
      final citas = c.read(agendaProvider).value!.agenda.citas;
      expect(citas.last.inicioEstimado, contains('11:20'));
    });

    test('si el servidor falla se revierte y devuelve el motivo', () async {
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'programada', 'Rosa')])),
        'POST /citas/1/iniciar': (_) => (status: 409, cuerpo: {'detail': 'Termina la cita en curso'}),
      });
      final c = await listo(red);
      final error = await c.read(agendaProvider.notifier).accion(AccionConsulta.iniciar, 1);
      expect(error, 'Termina la cita en curso');
      expect(c.read(agendaProvider).value!.agenda.citas.single.estado, 'programada');
    });

    test('+20 envía los minutos correctos', () async {
      Object? cuerpo;
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'en_curso', 'Rosa')])),
        'POST /citas/1/extender': (o) {
          cuerpo = o.data;
          return ok({
            'agenda': agendaJson([citaJson(1, 'en_curso', 'Rosa')]),
          });
        },
      });
      final c = await listo(red);
      await c.read(agendaProvider.notifier).accion(AccionConsulta.mas20, 1);
      expect(cuerpo, {'minutos': 20});
    });

    test('una descarga vieja no deshace una acción más reciente', () async {
      final soltar = Completer<void>();
      var primera = true;
      final red = _RedLenta(
        {
          'POST /auth/refresh': (_) => ok(tokens),
          'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'programada', 'Rosa')])),
          'POST /citas/1/iniciar': (_) => ok({
            'agenda': agendaJson([citaJson(1, 'en_curso', 'Rosa')]),
          }),
        },
        antes: (o) async {
          if (o.path == '/agenda' && !primera) await soltar.future;
          if (o.path == '/agenda') primera = false;
        },
      );
      final c = await listo(red);
      final refresco = c.read(agendaProvider.notifier).refrescar();
      await c.read(agendaProvider.notifier).accion(AccionConsulta.iniciar, 1);
      soltar.complete();
      await refresco;
      expect(c.read(agendaProvider).value!.agenda.citas.single.estado, 'en_curso');
    });

    test('sin señal muestra la última agenda guardada en modo lectura', () async {
      almacen.datos[claveAgendaGuardada] = jsonEncode(agendaJson([citaJson(1, 'programada', 'Rosa')]));
      final red = RedFalsa({'POST /auth/refresh': (_) => null, 'GET /agenda': (_) => null});
      final c = await listo(red);
      final estado = c.read(agendaProvider).value!;
      expect(estado.sinConexion, isTrue);
      expect(estado.agenda.citas.single.paciente.nombre, 'Rosa');
      final error = await c.read(agendaProvider.notifier).accion(AccionConsulta.iniciar, 1);
      expect(error, contains('modo lectura'));
      expect(red.llamadas, isNot(contains('POST /citas/1/iniciar')));
    });

    test('guarda la agenda descargada para cuando no haya señal', () async {
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'programada', 'Rosa')])),
      });
      await listo(red);
      expect(almacen.datos[claveAgendaGuardada], contains('Rosa'));
    });
  });

  group('pantallas', () {
    final hoy = agendaJson([citaJson(1, 'programada', 'Rosa Paz')]);

    Future<void> abrirHoy(WidgetTester t, RedFalsa red, AlmacenMemoria almacen) async {
      await t.binding.setSurfaceSize(const Size(360, 740)); // pantalla pequeña: RF-04 y RNF-12
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(app(red, almacen));
      await t.pumpAndSettle();
    }

    testWidgets('login incorrecto muestra el mensaje del servidor', (t) async {
      final red = RedFalsa({
        'POST /auth/login': (_) => (status: 401, cuerpo: {'detail': 'Correo o contraseña incorrectos.'}),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveModo] = 'negocio');
      expect(find.text('Entrar'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'a@b.test');
      await t.enterText(find.byType(TextField).last, 'mala');
      await t.tap(find.text('Entrar'));
      await t.pumpAndSettle();
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    });

    testWidgets('login correcto lleva a la agenda; Iniciar pasa a +10, +20 y Terminar', (t) async {
      final red = RedFalsa({
        'POST /auth/login': (_) => ok({
          ...tokens,
          'usuario': {'correo': 'a@b.test'},
        }),
        'GET /agenda': (_) => ok(hoy),
        'POST /citas/1/iniciar': (_) => ok({
          'agenda': agendaJson([citaJson(1, 'en_curso', 'Rosa Paz')], retraso: 15),
        }),
      });
      final almacen = AlmacenMemoria()..datos[claveModo] = 'negocio';
      await abrirHoy(t, red, almacen);
      await t.enterText(find.byType(TextField).first, 'a@b.test');
      await t.enterText(find.byType(TextField).last, 'clave');
      await t.tap(find.text('Entrar'));
      await t.pumpAndSettle();

      expect(find.textContaining('Rosa Paz'), findsWidgets);
      expect(find.text('Iniciar'), findsOneWidget);
      expect(almacen.datos[claveRenovacion], 'r2');

      await t.tap(find.text('Iniciar'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('me-demoro')), findsOneWidget);
      expect(find.text('Terminar'), findsOneWidget);
      expect(find.byKey(const Key('retraso')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('las acciones de una cita caben en un celular pequeño (sin «overflowed»)', (t) async {
      final red = RedFalsa({
        'POST /auth/login': (_) => ok({
          ...tokens,
          'usuario': {'correo': 'a@b.test'},
        }),
        'GET /agenda': (_) => ok(hoy),
      });
      await t.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(app(red, AlmacenMemoria()..datos[claveModo] = 'negocio'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'a@b.test');
      await t.enterText(find.byType(TextField).last, 'clave');
      await t.tap(find.text('Entrar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Rosa Paz'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(find.text('Cancelar cita'), 100, scrollable: find.byType(Scrollable).last);
      expect(find.text('Cancelar cita'), findsOneWidget);
    });

    testWidgets('un error al iniciar se avisa y deja el botón como estaba', (t) async {
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(hoy),
        'POST /citas/1/iniciar': (_) => (status: 409, cuerpo: {'detail': 'Termina la cita en curso'}),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      await t.tap(find.text('Iniciar'));
      await t.pumpAndSettle();
      expect(find.text('Termina la cita en curso'), findsOneWidget);
      expect(find.text('Iniciar'), findsOneWidget);
    });

    testWidgets('No vino pide confirmación antes de sumar la inasistencia', (t) async {
      fijarReloj(10, 30);
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(hoy),
        'POST /citas/1/no-asistio': (_) => ok({
          'agenda': agendaJson([citaJson(1, 'no_asistio', 'Rosa Paz')]),
        }),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      await t.tap(find.text('No vino'));
      await t.pumpAndSettle();
      expect(red.llamadas, isNot(contains('POST /citas/1/no-asistio')));
      await t.tap(find.widgetWithText(FilledButton, 'No vino'));
      await t.pumpAndSettle();
      expect(red.llamadas, contains('POST /citas/1/no-asistio'));
    });

    testWidgets('sin señal se ve la franja y no hay botones de consulta', (t) async {
      final red = RedFalsa({'POST /auth/refresh': (_) => null, 'GET /agenda': (_) => null});
      final almacen = AlmacenMemoria()
        ..datos[claveRenovacion] = 'r1'
        ..datos[claveAgendaGuardada] = jsonEncode(hoy);
      await abrirHoy(t, red, almacen);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.text('Iniciar'), findsNothing);
      expect(find.text('Nueva cita'), findsNothing);
    });

    testWidgets('Confirmar y avisar confirma la reserva y abre WhatsApp con el mensaje', (t) async {
      final lanzador = instalarLanzador();
      const whatsapp = 'https://wa.me/51987654321?text=Hola%20Rosa';
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(agendaJson([citaJson(5, 'por_aprobar', 'Rosa Paz')], porAprobar: 2)),
        'GET /citas/por-aprobar': (_) => ok({
          'citas': [citaJson(5, 'por_aprobar', 'Rosa Paz')],
        }),
        'POST /citas/5/aprobar': (_) => ok({
          'cita_id': 5,
          'estado': 'programada',
          'whatsapp_url': whatsapp,
          'siguientes': [],
          'agenda': agendaJson([citaJson(5, 'programada', 'Rosa Paz')], porAprobar: 1),
        }),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      expect(find.text('2 reservas por confirmar'), findsOneWidget);
      await t.tap(find.byKey(const Key('por-confirmar')));
      await t.pumpAndSettle();
      expect(find.text('Por confirmar'), findsOneWidget);
      await t.tap(find.text('Confirmar y avisar'));
      await t.pumpAndSettle();
      expect(red.llamadas, contains('POST /citas/5/aprobar'));
      expect(lanzador.abiertos, [whatsapp]); // directo, sin un diálogo de por medio
    });

    testWidgets('Recordatorios: Enviar abre WhatsApp y marca el recordatorio', (t) async {
      final lanzador = instalarLanzador();
      var enviado = false;
      Map<String, dynamic> fila() => {
        ...citaJson(7, 'programada', 'Ana Ruiz', hora: '09:00'),
        'whatsapp_url': 'https://wa.me/51987000001?text=Te%20recordamos',
        'recordatorio_enviado_en': enviado ? '2026-11-09T20:00:00-05:00' : null,
        'asistencia_confirmada': null,
      };
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(hoy),
        'GET /citas/recordatorios': (_) => ok({
          'fecha': '2026-11-10',
          'citas': [fila()],
        }),
        'POST /citas/7/recordado': (_) {
          enviado = true;
          return ok(fila());
        },
        'POST /citas/7/asistencia': (o) => ok({...fila(), 'asistencia_confirmada': true}),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      await t.tap(find.byTooltip('Recordatorios'));
      await t.pumpAndSettle();
      expect(find.text('Ana Ruiz'), findsOneWidget);
      expect(find.textContaining('0 de 1 recordatorios enviados'), findsOneWidget);
      await t.tap(find.text('Enviar'));
      await t.pumpAndSettle();
      expect(lanzador.abiertos, ['https://wa.me/51987000001?text=Te%20recordamos']);
      expect(red.llamadas, contains('POST /citas/7/recordado'));
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.textContaining('1 de 1 recordatorios enviados'), findsOneWidget);
      await t.tap(find.text('Confirmó'));
      await t.pumpAndSettle();
      expect(red.llamadas, contains('POST /citas/7/asistencia'));
    });

    testWidgets('tras No vino ofrece avisar al siguiente paciente', (t) async {
      fijarReloj(10, 30);
      final lanzador = instalarLanzador();
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(hoy),
        'POST /citas/1/no-asistio': (_) => ok({
          'cita_id': 1,
          'agenda': agendaJson([citaJson(1, 'no_asistio', 'Rosa Paz')]),
          'siguientes': [
            {
              'cita_id': 2,
              'paciente': 'Beto Paz',
              'inicio': '2026-11-09T11:00:00-05:00',
              'whatsapp_url': 'https://wa.me/51987000002?text=Se%20libero',
            },
          ],
        }),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      await t.tap(find.text('No vino'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'No vino'));
      await t.pumpAndSettle();
      expect(find.text('Quedó un espacio libre'), findsOneWidget);
      expect(find.text('Beto Paz'), findsOneWidget);
      await t.tap(find.text('Avisar'));
      await t.pumpAndSettle();
      expect(lanzador.abiertos, ['https://wa.me/51987000002?text=Se%20libero']);
      expect(find.text('Enviado'), findsOneWidget); // la hoja sigue abierta para avisar a otro
    });

    testWidgets('tratamientos: la duración real se aplica con un toque', (t) async {
      Map<String, dynamic>? guardado;
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(hoy),
        'GET /tratamientos': (_) => ok({
          'tratamientos': [
            {
              'id': 3,
              'nombre': 'Endodoncia',
              'duracion_min': 90,
              'margen_min': 10,
              'indicaciones': 'Come antes de venir.',
              'duracion_real_min': 120,
              'duracion_real_citas': 14,
            },
          ],
        }),
        'PUT /tratamientos/3': (o) {
          guardado = o.data as Map<String, dynamic>;
          return ok(guardado!);
        },
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      await t.tap(find.byIcon(Icons.settings_outlined));
      await t.pumpAndSettle();
      await t.tap(find.text('Tratamientos'));
      await t.pumpAndSettle();
      await t.tap(find.text('Endodoncia'));
      await t.pumpAndSettle();
      expect(find.text('En la práctica dura 120 min (14 citas).'), findsOneWidget);
      await t.tap(find.text('Usar este tiempo'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(guardado?['duracion_min'], 120);
      expect(guardado?['indicaciones'], 'Come antes de venir.');
    });

    testWidgets('vista de mes con el número de citas por día', (t) async {
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(hoy),
        'GET /agenda/semana': (_) => ok({'dias': []}),
        'GET /agenda/mes': (o) => ok({
          'anio': o.queryParameters['anio'],
          'mes': o.queryParameters['mes'],
          'dias': [
            for (var d = 1; d <= 30; d++)
              {
                'fecha': '2026-11-${d.toString().padLeft(2, '0')}',
                'citas': d == 9 ? 3 : 0,
                'por_confirmar': d == 9 ? 1 : 0,
                'bloqueo': d == 20,
              },
          ],
        }),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      await t.tap(find.byIcon(Icons.date_range));
      await t.pumpAndSettle();
      await t.tap(find.text('Mes'));
      await t.pumpAndSettle();
      expect(red.llamadas, contains('GET /agenda/mes'));
      expect(find.byKey(const Key('citas-2026-11-09')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('todos los botones de consulta miden 44 px o más', (t) async {
      final red = RedFalsa({
        'POST /auth/refresh': (_) => ok(tokens),
        'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'en_curso', 'Rosa Paz')])),
      });
      await abrirHoy(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
      for (final texto in ['Me demoro', 'Terminar']) {
        final boton = find.ancestor(
          of: find.text(texto),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(t.getSize(boton.first).height, greaterThanOrEqualTo(44));
      }
    });
  });
}

class _RedLenta extends RedFalsa {
  _RedLenta(super.rutas, {required this.antes});

  final Future<void> Function(RequestOptions) antes;

  @override
  Future<ResponseBody> fetch(options, requestStream, cancelFuture) async {
    await antes(options);
    return super.fetch(options, requestStream, cancelFuture);
  }
}
