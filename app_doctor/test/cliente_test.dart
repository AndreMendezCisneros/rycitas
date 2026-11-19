import 'dart:convert';
import 'dart:io';

import 'package:denticita_doctor/core/api.dart';
import 'package:denticita_doctor/core/apariencia.dart';
import 'package:denticita_doctor/core/modo.dart';
import 'package:denticita_doctor/features/cliente/inicio_cliente.dart';
import 'package:denticita_doctor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_10y.dart' as zonas;

import 'apoyo.dart';

Respuesta ok(Object cuerpo) => (status: 200, cuerpo: cuerpo);

const _tokens = {'acceso': 'a1', 'renovacion': 'r2'};

final _yo = {
  'nombre': 'Rosa Paz',
  'correo': 'rosa@correo.pe',
  'celular': '+51987654321',
  'codigo_referido': 'K7PQ2M',
  'invitados': 0,
  'celular_verificado': true,
  'verificacion_activa': false,
};

final _tarjeta = {
  'activa': true,
  'sellos': 2,
  'meta': 5,
  'premio': 'Un Hydrafacial gratis',
  'lista': false,
  'puntualidad': true,
  'historial': [],
  'nivel': {'clave': 'bronce', 'nombre': 'Bronce', 'visitas': 2, 'siguiente': 'Plata', 'faltan': 1},
};

final _cupon = {
  'id': 7,
  'codigo': 'GLOW20',
  'titulo': '20 % en tu facial',
  'descuento': '20 %',
  'servicio': null,
  'servicio_slug': null,
  'vence_el': '2026-12-09',
};

final _glow = {
  'slug': 'glowclinic',
  'nombre': 'GlowClinic',
  'rubro': 'estetica',
  'rubro_nombre': 'Estética',
  'direccion': 'Av. Larco 123',
  'foto': null,
  'acepta_reservas': true,
  'fidelidad': true,
  'ultima_cita': '2026-11-02T10:00:00-05:00',
  'sellos': 2,
  'meta': 5,
  'nivel': 'Bronce',
  'cupones': 1,
  'silenciado': false,
};

final _ficha = {
  ..._glow,
  'opciones': {'elegir_profesional': true},
  'profesionales': [
    {'id': 1, 'nombre': 'Lic. Ana Martínez', 'detalle': '', 'servicios': null},
    {'id': 2, 'nombre': 'Carlos Ruiz', 'detalle': '', 'servicios': null},
  ],
  'motivos': [
    {'slug': 'hydrafacial', 'nombre': 'Hydrafacial', 'duracion_min': 60, 'precio_desde': '180'},
  ],
  'mapa_url': '',
  'whatsapp': '51911111111',
  'es_cliente': true,
  'tarjeta': _tarjeta,
  'cupones': [_cupon],
};

Map<String, Respuesta? Function(dynamic)> _rutasCliente({List<Map<String, dynamic>>? enviados}) => {
  'POST /auth/refresh': (_) => ok(_tokens),
  'GET /yo': (_) => ok(_yo),
  'GET /mis-negocios': (_) => ok({
    'negocios': [_glow],
    'celular_verificado': true,
  }),
  'GET /negocios': (_) => ok({
    'negocios': [_glow],
    'rubros': [
      {'clave': 'estetica', 'nombre': 'Estética'},
    ],
  }),
  'GET /negocios/glowclinic': (_) => ok(_ficha),
  'GET /negocios/glowclinic/disponibilidad': (_) => ok({
    'dias': [
      {
        'fecha': '2026-11-10',
        'horas': ['2026-11-10T10:00:00-05:00', '2026-11-10T11:00:00-05:00'],
      },
    ],
  }),
  'POST /negocios/glowclinic/reservas': (o) {
    final cuerpo = o.data is String ? jsonDecode(o.data as String) : o.data;
    enviados?.add(Map<String, dynamic>.from(cuerpo as Map));
    return (
      status: 201,
      cuerpo: {'token': 't1', 'inicio': '2026-11-10T11:00:00-05:00', 'tratamiento': 'Hydrafacial', 'cupon': _cupon},
    );
  },
  'GET /mis-citas': (_) => ok({'proximas': [], 'pasadas': []}),
  'GET /logros': (_) => ok({
    'logros': [
      {
        'clave': 'primera',
        'titulo': 'Primera cita',
        'como': 'Completa tu primera visita.',
        'progreso': 1,
        'meta': 1,
        'logrado': true,
        'icono': 'estrella',
      },
      {
        'clave': 'fiel',
        'titulo': 'Cliente fiel',
        'como': 'Completa 5 visitas.',
        'progreso': 1,
        'meta': 5,
        'logrado': false,
        'icono': 'corazon',
      },
    ],
    'visitas': 1,
    'puntos': 25,
    'racha': 1,
    'racha_activa': true,
    'nivel': {'nombre': 'Nueva', 'siguiente': 'Habitual', 'faltan': 2, 'progreso': 0.33},
  }),
  'GET /beneficios': (_) => ok({
    'tarjetas': [
      {
        'negocio': {'slug': 'glowclinic', 'nombre': 'GlowClinic'},
        ..._tarjeta,
      },
    ],
    'cupones': [
      {
        'negocio': {'slug': 'glowclinic', 'nombre': 'GlowClinic'},
        ..._cupon,
      },
    ],
    'codigo_referido': 'K7PQ2M',
  }),
};

Widget _app(RedFalsa red, AlmacenMemoria almacen) => ProviderScope(
  overrides: [almacenProvider.overrideWithValue(almacen), adaptadorHttpProvider.overrideWithValue(red)],
  child: const RyCitasApp(),
);

Future<void> _abrir(WidgetTester t, RedFalsa red, AlmacenMemoria almacen) async {
  await t.binding.setSurfaceSize(const Size(400, 860));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(_app(red, almacen));
  await t.pumpAndSettle();
}

AlmacenMemoria _conSesionCliente() => AlmacenMemoria()
  ..datos[claveModo] = 'cliente'
  ..datos[claveRenovacionCliente] = 'r1';

Map<String, dynamic> _pasada(int id, String estado, String slug, String nombre, String inicio) => {
  'id': id,
  'estado': estado,
  'estado_texto': {'terminada': 'Atendida', 'no_asistio': 'No asististe', 'cancelada': 'Cancelada'}[estado],
  'inicio': inicio,
  'fin': inicio,
  'tratamiento': 'Limpieza facial',
  'tratamiento_slug': 'limpieza-facial',
  'profesional': 'Ana',
  'precio_texto': 'S/ 80',
  'notas': '',
  'negocio': {'slug': slug, 'nombre': nombre},
  'consultorio': {'nombre': nombre, 'direccion': 'Av. Sol 123', 'mapa_url': '', 'whatsapp': '+51999888777'},
};

Map<String, dynamic> _historial(List<Map<String, dynamic>> citas, {bool hayMas = false, bool completo = true}) => {
  'citas': citas,
  'hay_mas': hayMas,
  'visitas': 3,
  'negocios': [
    {'slug': 'glowclinic', 'nombre': 'Glow Clinic'},
    {'slug': 'barber', 'nombre': 'Barber Wari'},
  ],
  'completo': completo,
};

void main() {
  test('lee token y firma del enlace de la cita que llega por WhatsApp', () {
    final e = leerEnlaceDeCita('Mira tu cita: https://sonrisawari.ryjec.com/c/Ab_9-x/?v=0f3a9c ');
    expect(e?.token, 'Ab_9-x');
    expect(e?.firma, '0f3a9c');
    expect(leerEnlaceDeCita('https://sonrisawari.ryjec.com/c/Ab9/')?.firma, '');
    expect(leerEnlaceDeCita('hola'), isNull);
  });

  setUpAll(() async {
    zonas.initializeTimeZones();
    await initializeDateFormatting('es');
    await cargarFuentesReales();
  });

  testWidgets('sin sesión pregunta el modo; «Quiero reservar» registra y muestra sus lugares', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'POST /auth/registro': (_) => ok({..._tokens, 'nuevo': true, 'cliente': _yo}),
    });
    final almacen = AlmacenMemoria();
    await _abrir(t, red, almacen);
    expect(find.text('Quiero reservar'), findsOneWidget);
    expect(find.text('Tengo un negocio'), findsOneWidget);

    await t.tap(find.byKey(const Key('modo-cliente')));
    await t.pumpAndSettle();
    expect(almacen.datos[claveModo], 'cliente');
    await t.enterText(find.byKey(const Key('cliente-nombre')), 'Rosa Paz');
    await t.enterText(find.byKey(const Key('cliente-correo')), 'rosa@correo.pe');
    await t.enterText(find.byKey(const Key('cliente-celular')), '987654321');
    await t.enterText(find.byKey(const Key('cliente-clave')), 'secreta-123');
    await t.ensureVisible(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    expect(find.textContaining('Acepta la política'), findsOneWidget); // sin aceptar no envía
    expect(red.llamadas, isNot(contains('POST /auth/registro')));

    await t.ensureVisible(find.byKey(const Key('cliente-acepta')));
    await t.tap(find.byKey(const Key('cliente-acepta')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    expect(red.llamadas, contains('POST /auth/registro'));
    expect(almacen.datos[claveRenovacionCliente], 'r2');
    expect(almacen.datos.containsKey(claveRenovacion), isFalse); // la sesión del negocio no se toca
    expect(find.text('¡Hola, Rosa!'), findsOneWidget);
    expect(find.text('TUS LUGARES'), findsOneWidget);
    expect(find.text('GlowClinic'), findsOneWidget);
    expect(find.text('2/5 sellos'), findsOneWidget);
    expect(find.text('1 cupón'), findsOneWidget);
  });

  testWidgets('«Ya tengo cuenta» entra con correo y contraseña', (t) async {
    Object? cuerpo;
    final red = RedFalsa({
      ..._rutasCliente(),
      'POST /auth/entrar': (o) {
        cuerpo = o.data is String ? jsonDecode(o.data as String) : o.data;
        return ok({..._tokens, 'nuevo': false, 'cliente': _yo});
      },
    });
    final almacen = AlmacenMemoria()..datos[claveModo] = 'cliente';
    await _abrir(t, red, almacen);
    await t.tap(find.text('Ya tengo cuenta'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cliente-nombre')), findsNothing); // solo correo y contraseña
    expect(find.byKey(const Key('cliente-celular')), findsNothing);
    await t.enterText(find.byKey(const Key('cliente-correo')), 'rosa@correo.pe');
    await t.enterText(find.byKey(const Key('cliente-clave')), 'secreta-123');
    await t.tap(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    expect(cuerpo, {'correo': 'rosa@correo.pe', 'clave': 'secreta-123'});
    expect(almacen.datos[claveRenovacionCliente], 'r2');
    expect(find.text('¡Hola, Rosa!'), findsOneWidget);
  });

  testWidgets('crear una cuenta con un correo que ya existe lleva a «Ya tengo cuenta»', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'POST /auth/registro': (_) => (
        status: 409,
        cuerpo: {'codigo': 'cuenta_existe', 'detail': 'Ya tienes una cuenta con ese correo. Entra con tu contraseña.'},
      ),
    });
    await _abrir(t, red, AlmacenMemoria()..datos[claveModo] = 'cliente');
    await t.enterText(find.byKey(const Key('cliente-nombre')), 'Rosa Paz');
    await t.enterText(find.byKey(const Key('cliente-correo')), 'rosa@correo.pe');
    await t.enterText(find.byKey(const Key('cliente-celular')), '987654321');
    await t.enterText(find.byKey(const Key('cliente-clave')), 'secreta-123');
    await t.ensureVisible(find.byKey(const Key('cliente-acepta')));
    await t.tap(find.byKey(const Key('cliente-acepta')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    expect(find.textContaining('Ya tienes una cuenta'), findsOneWidget);
    expect(find.byKey(const Key('cliente-nombre')), findsNothing); // ya está en «Ya tengo cuenta»
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('reserva desde la app: con quién, hora y cupón', (t) async {
    final enviados = <Map<String, dynamic>>[];
    final red = RedFalsa(_rutasCliente(enviados: enviados));
    await _abrir(t, red, _conSesionCliente());

    await t.tap(find.byKey(const Key('negocio-glowclinic')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('tarjeta-sellos')), findsOneWidget);
    expect(find.textContaining('Te faltan 3 para: Un Hydrafacial gratis'), findsOneWidget);

    await t.scrollUntilVisible(find.byKey(const Key('servicio-hydrafacial')), 200);
    await t.tap(find.byKey(const Key('servicio-hydrafacial')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('paso-quien')), findsOneWidget);
    await t.tap(find.byKey(const Key('quien-2')));
    await t.pumpAndSettle();
    await t.tap(find.text('11:00'));
    await t.pumpAndSettle();
    expect(find.text('Con Carlos Ruiz'), findsOneWidget);
    await t.enterText(find.byKey(const Key('campo-notas')), 'Piel sensible');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('usar-cupon-GLOW20')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('usar-cupon-GLOW20')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('confirmar-reserva')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirmar-reserva')));
    await t.pumpAndSettle();

    expect(find.text('¡Reserva enviada!'), findsOneWidget);
    expect(find.text('Por confirmar'), findsOneWidget);
    expect(enviados.single, {
      'motivo': 'hydrafacial',
      'inicio': '2026-11-10T11:00:00-05:00',
      'profesional': 2,
      'cupon': 7,
      'notas': 'Piel sensible',
    });
  });

  testWidgets('beneficios: tarjeta de sellos, cupones y código para invitar', (t) async {
    final red = RedFalsa(_rutasCliente());
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Beneficios'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cupon-GLOW20')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('tarjeta-sellos')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('tarjeta-sellos')), findsOneWidget);
    expect(find.byKey(const Key('seccion-logros')), findsOneWidget);
    expect(find.byKey(const Key('logro-primera')), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const Key('codigo-referido')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('K7PQ2M'), findsOneWidget);
  });

  testWidgets('el historial muestra las citas pasadas por mes, filtra por lugar y carga más', (t) async {
    final pedidos = <Map<String, dynamic>>[];
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /mis-citas/historial': (o) {
        pedidos.add(o.queryParameters);
        if (o.queryParameters['antes'] != null) {
          return ok(_historial([_pasada(3, 'terminada', 'glowclinic', 'Glow Clinic', '2026-08-02T15:00:00-05:00')]));
        }
        if (o.queryParameters['negocio'] == 'barber') {
          return ok(_historial([_pasada(2, 'no_asistio', 'barber', 'Barber Wari', '2026-10-20T10:00:00-05:00')]));
        }
        return ok(
          _historial([
            _pasada(1, 'terminada', 'glowclinic', 'Glow Clinic', '2026-11-03T16:00:00-05:00'),
            _pasada(2, 'no_asistio', 'barber', 'Barber Wari', '2026-10-20T10:00:00-05:00'),
          ], hayMas: true),
        );
      },
    });
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Mis citas'));
    await t.pumpAndSettle();
    await t.tap(find.text('Historial'));
    await t.pumpAndSettle();
    expect(find.text('3 visitas · 2 lugares'), findsOneWidget);
    expect(find.text('NOVIEMBRE 2026'), findsOneWidget);
    expect(find.text('OCTUBRE 2026'), findsOneWidget);
    expect(find.byKey(const Key('cita-cliente-1')), findsOneWidget);
    expect(find.byKey(const Key('reservar-de-nuevo-1')), findsOneWidget);
    expect(find.byKey(const Key('reservar-de-nuevo-2')), findsNothing); // no asistió: sin «Reservar de nuevo»
    expect(find.byKey(const Key('faltan-citas')), findsNothing);

    await t.scrollUntilVisible(
      find.byKey(const Key('historial-ver-mas')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const Key('historial-ver-mas')));
    await t.pumpAndSettle();
    expect(pedidos.last['antes'], '2026-10-20T10:00:00-05:00');
    expect(find.text('AGOSTO 2026'), findsOneWidget);

    await t.scrollUntilVisible(find.byKey(const Key('filtro-barber')), -200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('filtro-barber')));
    await t.pumpAndSettle();
    expect(pedidos.last['negocio'], 'barber');
    expect(find.byKey(const Key('cita-cliente-1')), findsNothing);
    expect(find.byKey(const Key('cita-cliente-2')), findsOneWidget);
  });

  testWidgets('sin el WhatsApp probado el historial explica cómo traer las demás citas', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /mis-citas/historial': (_) => ok(_historial(const [], completo: false)),
    });
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Mis citas'));
    await t.pumpAndSettle();
    await t.tap(find.text('Historial'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('faltan-citas')), findsOneWidget);
    expect(find.text('Pegar el enlace de mi cita'), findsOneWidget);
  });

  testWidgets('«Reservar de nuevo» abre la reserva de ese servicio en ese lugar', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /mis-citas/historial': (_) =>
          ok(_historial([_pasada(1, 'terminada', 'glowclinic', 'Glow Clinic', '2026-11-03T16:00:00-05:00')])),
    });
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Mis citas'));
    await t.pumpAndSettle();
    await t.tap(find.text('Historial'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('reservar-de-nuevo-1')));
    await t.pumpAndSettle();
    expect(red.llamadas, contains('GET /negocios/glowclinic'));
  });

  testWidgets('cerrar sesión vuelve a la elección del modo', (t) async {
    final red = RedFalsa({..._rutasCliente(), 'POST /auth/logout': (_) => (status: 204, cuerpo: null)});
    final almacen = _conSesionCliente();
    await _abrir(t, red, almacen);
    await t.tap(find.text('Perfil'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('cliente-salir')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cliente-salir')));
    await t.pumpAndSettle();
    expect(find.text('Quiero reservar'), findsOneWidget);
    expect(almacen.datos.containsKey(claveRenovacionCliente), isFalse);
    expect(almacen.datos.containsKey(claveModo), isFalse);
  });

  testWidgets('quien ya usaba la app del negocio entra directo, sin elegir modo', (t) async {
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(_tokens),
      'GET /agenda': (_) => ok(agendaJson([citaJson(1, 'programada', 'Luis Rojas')])),
    });
    await _abrir(t, red, AlmacenMemoria()..datos[claveRenovacion] = 'r1');
    expect(find.text('Quiero reservar'), findsNothing);
    expect(find.textContaining('Luis Rojas'), findsWidgets);
  });

  Map<String, dynamic> proxima({bool puedeCambiar = true}) => {
    ..._pasada(5, 'programada', 'glowclinic', 'Glow Clinic', '2030-03-10T10:00:00-05:00'),
    'estado_texto': 'Confirmada',
    'motivo': 'hydrafacial',
    'profesional_id': 1,
    'puede_cambiar': puedeCambiar,
    'cambia_hasta': '2030-03-10T06:00:00-05:00',
  };

  testWidgets('el cliente cancela su cita desde el detalle', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /mis-citas': (_) => ok({
        'proximas': [proxima()],
        'pasadas': [],
      }),
      'POST /mis-citas/5/cancelar': (_) => ok({...proxima(), 'estado': 'cancelada'}),
    });
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Mis citas'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('proxima-5')).last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cliente-reprogramar')), findsOneWidget);
    expect(find.textContaining('Puedes cancelarla o moverla hasta'), findsOneWidget);
    await t.tap(find.byKey(const Key('cliente-cancelar')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar cita'));
    await t.pumpAndSettle();
    expect(red.llamadas, contains('POST /mis-citas/5/cancelar'));
  });

  testWidgets('fuera de plazo no deja cambiarla y explica que escriba por WhatsApp', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /mis-citas': (_) => ok({
        'proximas': [proxima(puedeCambiar: false)],
        'pasadas': [],
      }),
    });
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Mis citas'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('proxima-5')).last);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cliente-cancelar')), findsNothing);
    expect(find.byKey(const Key('fuera-de-plazo')), findsOneWidget);
  });

  testWidgets('«¿Cómo funciona?» explica sellos, cupones, racha y nivel', (t) async {
    await _abrir(t, RedFalsa(_rutasCliente()), _conSesionCliente());
    await t.tap(find.text('Beneficios'));
    await t.pumpAndSettle();
    expect(find.textContaining('puntos'), findsNothing);
    await t.tap(find.byKey(const Key('abrir-como-funciona')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('como-funciona')), findsOneWidget);
    expect(find.text('Tarjeta de sellos'), findsWidgets);
    await t.scrollUntilVisible(
      find.text('Racha'),
      200,
      scrollable: find.descendant(of: find.byKey(const Key('como-funciona')), matching: find.byType(Scrollable)),
    );
    expect(find.text('Racha'), findsOneWidget);
  });

  testWidgets('si hoy no quedan horas por la anticipación, lo dice', (t) async {
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /negocios/glowclinic': (_) => ok({
        ..._ficha,
        'opciones': {'elegir_profesional': false},
        'siguiendo': true,
        'promos': false,
      }),
      'GET /negocios/glowclinic/disponibilidad': (_) => ok({
        'dias': [
          {
            'fecha': '2030-03-11',
            'horas': ['2030-03-11T10:00:00-05:00'],
          },
        ],
        'motivo_hoy': 'anticipacion',
        'anticipacion_horas': 2,
        'whatsapp': '51911111111',
      }),
    });
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.byKey(const Key('negocio-glowclinic')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('switch-promos')), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const Key('servicio-hydrafacial')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const Key('servicio-hydrafacial')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('aviso-hoy')), findsOneWidget);
    expect(find.textContaining('al menos 2 h de anticipación'), findsOneWidget);
  });

  testWidgets('capturas del modo cliente', (t) async {
    if (carpetaCapturas == null) return;
    final tema = Platform.environment['TEMA'] ?? 'claro';
    final red = RedFalsa({
      ..._rutasCliente(),
      'GET /mis-citas/historial': (_) => ok(
        _historial([
          _pasada(1, 'terminada', 'glowclinic', 'Glow Clinic', '2026-11-03T16:00:00-05:00'),
          _pasada(2, 'no_asistio', 'barber', 'Barber Wari', '2026-10-20T10:00:00-05:00'),
          _pasada(3, 'terminada', 'glowclinic', 'Glow Clinic', '2026-10-02T15:00:00-05:00'),
        ], completo: false),
      ),
    });
    await _abrir(t, red, _conSesionCliente()..datos[claveTema] = tema);
    await capturar(t, 'cliente-inicio-$tema');
    await t.tap(find.byKey(const Key('rubi')));
    await t.pumpAndSettle();
    await capturar(t, 'cliente-rubi-$tema');
    await t.tapAt(const Offset(200, 40));
    await t.pumpAndSettle();
    await t.tap(find.text('Mis citas'));
    await t.pumpAndSettle();
    await capturar(t, 'cliente-citas-$tema');
    await t.tap(find.text('Historial'));
    await t.pumpAndSettle();
    await capturar(t, 'cliente-historial-$tema');
    await t.tap(find.text('Beneficios'));
    await t.pumpAndSettle();
    await capturar(t, 'cliente-beneficios-$tema');
    await t.tap(find.text('Perfil'));
    await t.pumpAndSettle();
    await capturar(t, 'cliente-perfil-$tema');
    await t.tap(find.text('Inicio'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('negocio-glowclinic')));
    await t.pumpAndSettle();
    await capturar(t, 'cliente-negocio-$tema');
  });

  testWidgets('capturas de la entrada del cliente', (t) async {
    if (carpetaCapturas == null) return;
    final tema = Platform.environment['TEMA'] ?? 'claro';
    await t.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _app(
        RedFalsa(_rutasCliente()),
        AlmacenMemoria()
          ..datos[claveModo] = 'cliente'
          ..datos[claveTema] = tema,
      ),
    );
    await t.pumpAndSettle();
    await capturar(t, 'entrada-crear-$tema');
    await t.tap(find.text('Ya tengo cuenta'));
    await t.pumpAndSettle();
    await capturar(t, 'entrada-entrar-$tema');
  });
}
