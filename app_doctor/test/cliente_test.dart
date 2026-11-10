import 'dart:convert';

import 'package:denticita_doctor/core/api.dart';
import 'package:denticita_doctor/core/modo.dart';
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
      cuerpo: {
        'token': 't1',
        'inicio': '2026-11-10T11:00:00-05:00',
        'tratamiento': 'Hydrafacial',
        'cupon': _cupon,
      },
    );
  },
  'GET /mis-citas': (_) => ok({'proximas': [], 'pasadas': []}),
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

void main() {
  setUpAll(() async {
    zonas.initializeTimeZones();
    await initializeDateFormatting('es');
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
    await t.ensureVisible(find.byKey(const Key('cliente-entrar')));
    await t.tap(find.byKey(const Key('cliente-entrar')));
    await t.pumpAndSettle();
    expect(find.textContaining('Acepta la política'), findsOneWidget); // sin aceptar no envía
    expect(red.llamadas, isNot(contains('POST /auth/registro')));

    await t.ensureVisible(find.byKey(const Key('cliente-acepta')));
    await t.tap(find.byKey(const Key('cliente-acepta')));
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('cliente-entrar')));
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
    await t.tap(find.byKey(const Key('usar-cupon-GLOW20')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirmar-reserva')));
    await t.pumpAndSettle();

    expect(find.text('¡Reserva enviada!'), findsOneWidget);
    expect(enviados.single, {
      'motivo': 'hydrafacial',
      'inicio': '2026-11-10T11:00:00-05:00',
      'profesional': 2,
      'cupon': 7,
    });
  });

  testWidgets('beneficios: tarjeta de sellos, cupones y código para invitar', (t) async {
    final red = RedFalsa(_rutasCliente());
    await _abrir(t, red, _conSesionCliente());
    await t.tap(find.text('Beneficios'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cupon-GLOW20')), findsOneWidget);
    expect(find.byKey(const Key('tarjeta-sellos')), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('codigo-referido')));
    expect(find.text('K7PQ2M'), findsOneWidget);
  });

  testWidgets('cerrar sesión vuelve a la elección del modo', (t) async {
    final red = RedFalsa({..._rutasCliente(), 'POST /auth/logout': (_) => (status: 204, cuerpo: null)});
    final almacen = _conSesionCliente();
    await _abrir(t, red, almacen);
    await t.tap(find.text('Perfil'));
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
}
