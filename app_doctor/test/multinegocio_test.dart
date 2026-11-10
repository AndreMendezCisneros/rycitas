import 'package:denticita_doctor/core/api.dart';
import 'package:denticita_doctor/core/fechas.dart';
import 'package:denticita_doctor/features/auth/bloqueo.dart';
import 'package:denticita_doctor/main.dart';
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

class AutenticadorFalso implements Autenticador {
  var respuesta = true;
  var llamadas = 0;

  @override
  Future<bool> autenticar(String motivo) async {
    llamadas++;
    return respuesta;
  }

  @override
  Future<bool> disponible() async => true;
}

Map<String, dynamic> negocioJson({
  String rubro = 'barberia',
  String modo = 'por_profesional',
  int? miProfesional = 1,
  bool ofertable = true,
}) => {
  'nombre': 'Barbería Wari',
  'slug': 'wari',
  'rubro': rubro,
  'rubro_nombre': 'Barbería',
  'color': '#8a5a2b',
  'vocabulario': {
    'cliente': 'cliente',
    'clientes': 'clientes',
    'servicio': 'servicio',
    'servicios': 'servicios',
    'profesional': 'barbero',
    'profesionales': 'barberos',
    'local': 'barbería',
    'el_local': 'la barbería',
  },
  'suspendido': false,
  'opciones': {
    'modo_agenda': modo,
    'precio_ofertable': ofertable,
    'adelantos': false,
    'llegar_antes_min': 5,
    'tolerancia_inasistencia_min': 10,
  },
  'profesionales': [
    {'id': 1, 'nombre': 'Juan', 'detalle': ''},
    {'id': 2, 'nombre': 'Pedro', 'detalle': ''},
  ],
  'cuenta': {'correo': 'juan@wari.test', 'nombre': 'Juan', 'profesional_id': miProfesional},
};

Map<String, dynamic> conBarbero(Map<String, dynamic> cita, {int id = 1, String nombre = 'Juan'}) => {
  ...cita,
  'profesional': {'id': id, 'nombre': nombre},
};

void fijarReloj(int hora, int minuto) {
  Fechas.reloj = () => tz.TZDateTime(Fechas.lima, 2026, 11, 9, hora, minuto);
  addTearDown(() => Fechas.reloj = Fechas.relojReal);
}

Future<void> abrir(WidgetTester t, RedFalsa red, AlmacenMemoria almacen, {Autenticador? autenticador}) async {
  await t.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        almacenProvider.overrideWithValue(almacen),
        adaptadorHttpProvider.overrideWithValue(red),
        if (autenticador != null) autenticadorProvider.overrideWithValue(autenticador),
      ],
      child: const RyCitasApp(),
    ),
  );
  await t.pumpAndSettle();
}

AlmacenMemoria conSesion() => AlmacenMemoria()..datos[claveRenovacion] = 'r1';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    zonas.initializeTimeZones();
    await initializeDateFormatting('es');
  });

  final hoy = agendaJson([conBarbero(citaJson(1, 'programada', 'Rosa Paz'))]);

  testWidgets('una barbería habla de clientes y servicios', (t) async {
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(hoy),
    });
    await abrir(t, red, conSesion());
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Pacientes'), findsNothing);
    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Barbería Wari'), findsOneWidget);
  });

  testWidgets('sin /negocio (servidor anterior) sigue hablando como un consultorio', (t) async {
    final red = RedFalsa({'POST /auth/refresh': (_) => ok(tokens), 'GET /agenda': (_) => ok(hoy)});
    await abrir(t, red, conSesion());
    expect(find.text('Pacientes'), findsOneWidget);
    expect(find.byKey(const Key('filtro-profesional')), findsNothing);
  });

  testWidgets('la cuenta de un profesional solo ve su agenda: sin filtro ni «Con …»', (t) async {
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(hoy),
    });
    await abrir(t, red, conSesion());
    expect(find.byKey(const Key('filtro-profesional')), findsNothing);
    expect(find.text('Con Juan'), findsNothing);
    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    expect(find.text('Solo tu agenda (Juan)'), findsOneWidget);
    expect(find.text('Turnos de la agenda'), findsNothing); // la configuración es de la cuenta general
  });

  testWidgets('la cuenta general ve con quién es cada cita y filtra por profesional', (t) async {
    final pedidos = <Map<String, dynamic>>[];
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson(miProfesional: null)),
      'GET /agenda': (o) {
        pedidos.add(o.queryParameters);
        return ok(hoy);
      },
    });
    await abrir(t, red, conSesion());
    expect(find.text('Con Juan'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    await t.tap(find.byKey(const Key('filtro-profesional')));
    await t.pumpAndSettle();
    await t.tap(find.text('Pedro').last);
    await t.pumpAndSettle();
    expect(pedidos.last['profesional'], 2);
  });

  testWidgets('la agenda se divide en turnos con sus por confirmar arriba', (t) async {
    fijarReloj(8, 0);
    final agenda = {
      ...agendaJson([
        conBarbero(citaJson(1, 'programada', 'Rosa Paz')),
        conBarbero(citaJson(2, 'por_aprobar', 'Ana Ruiz', hora: '11:00')),
        conBarbero(citaJson(3, 'programada', 'Luis Soto', hora: '16:00'), id: 2, nombre: 'Pedro'),
      ], porAprobar: 1),
      'turnos': [
        {'nombre': 'Mañana', 'desde': 0, 'hasta': 780, 'citas': 2, 'por_confirmar': 1},
        {'nombre': 'Tarde', 'desde': 780, 'hasta': 1440, 'citas': 1, 'por_confirmar': 0},
      ],
    };
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson(miProfesional: null)),
      'GET /agenda': (_) => ok(agenda),
    });
    await abrir(t, red, conSesion());
    expect(find.text('Turno mañana'), findsOneWidget);
    expect(find.byKey(const Key('turno-Mañana-por-confirmar')), findsOneWidget);
    expect(find.text('1 por confirmar'), findsOneWidget);
    expect(find.text('POR CONFIRMAR'), findsOneWidget);
    // Dentro del turno, lo que falta confirmar va antes que la agenda, aunque sea más tarde.
    final yAna = t.getTopLeft(find.text('Ana Ruiz')).dy;
    expect(yAna, lessThan(t.getTopLeft(find.text('Rosa Paz')).dy));
    await t.scrollUntilVisible(find.text('Turno tarde'), 200);
    expect(find.text('Luis Soto'), findsOneWidget);
    expect(find.text('Con Pedro'), findsOneWidget);
    // Plegar la mañana esconde sus citas.
    await t.ensureVisible(find.text('Turno mañana'));
    await t.pumpAndSettle();
    final enManana = find.descendant(of: find.byKey(const Key('turno-Mañana')), matching: find.text('Rosa Paz'));
    expect(enManana, findsOneWidget);
    await t.tap(find.text('Turno mañana'));
    await t.pumpAndSettle();
    expect(enManana, findsNothing);
  });

  testWidgets('nueva cita: la cuenta general elige con quién y eso viaja a la API', (t) async {
    Map<String, dynamic>? horasPedidas;
    Map<String, dynamic>? creada;
    final negocio = negocioJson(miProfesional: null);
    (negocio['profesionales'] as List).add({
      'id': 3,
      'nombre': 'Lucho',
      'detalle': '',
      'servicios': [9],
    });
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocio),
      'GET /agenda': (_) => ok(hoy),
      'GET /tratamientos': (_) => ok({
        'tratamientos': [
          {'id': 1, 'nombre': 'Corte clásico', 'duracion_min': 30},
        ],
      }),
      'GET /citas/disponibilidad': (o) {
        horasPedidas = o.queryParameters;
        return ok({
          'dias': [
            {
              'fecha': '2026-11-10',
              'horas': ['2026-11-10T10:00:00-05:00'],
            },
          ],
        });
      },
      'POST /citas': (o) {
        creada = o.data as Map<String, dynamic>;
        return (status: 201, cuerpo: {'cita_id': 9, 'estado': 'programada', 'whatsapp_url': null, 'agenda': hoy});
      },
    });
    await abrir(t, red, conSesion());
    await t.tap(find.text('Nueva cita'));
    await t.pumpAndSettle();
    await t.tap(find.text('Corte clásico'));
    await t.pumpAndSettle();
    expect(find.text('Nueva cita · paso 2 de 4'), findsOneWidget);
    expect(find.byKey(const Key('quien-cualquiera')), findsOneWidget);
    expect(find.byKey(const Key('quien-3')), findsNothing); // Lucho no hace ese servicio
    await t.tap(find.text('Pedro'));
    await t.pumpAndSettle();
    expect(horasPedidas?['profesional'], 2);
    await t.tap(find.text('10:00').first);
    await t.pumpAndSettle();
    expect(find.textContaining('con Pedro'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'Ana Paz');
    await t.enterText(find.byType(TextField).at(1), '987654321');
    await t.tap(find.text('Registrar cita'));
    await t.pumpAndSettle();
    expect(creada?['profesional_id'], 2);
  });

  testWidgets('notificaciones: se apaga un tipo y la cuenta general elige los minutos', (t) async {
    final guardados = <Map<String, dynamic>>[];
    Map<String, dynamic> avisos(List<String> apagados, int minutos) => {
      'tipos': [
        for (final (tipo, nombre) in [
          ('por_aprobar', 'Reservas por confirmar'),
          ('nueva_cita', 'Citas nuevas'),
          ('cita_proxima', 'Antes de cada cita'),
          ('recordatorios', 'Agenda de mañana (8 p. m.)'),
        ])
          {'tipo': tipo, 'nombre': nombre, 'activo': !apagados.contains(tipo)},
      ],
      'recordar_cita_min': minutos,
      'puede_cambiar_minutos': true,
    };
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson(miProfesional: null)),
      'GET /agenda': (_) => ok(hoy),
      'GET /avisos': (_) => ok(avisos([], 30)),
      'PUT /avisos': (o) {
        final datos = (o.data as Map).cast<String, dynamic>();
        guardados.add(datos);
        return ok(
          avisos([for (final a in datos['apagados'] as List) a as String], (datos['recordar_cita_min'] as int?) ?? 30),
        );
      },
    });
    await abrir(t, red, conSesion());
    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Notificaciones'), 200);
    await t.tap(find.text('Notificaciones'));
    await t.pumpAndSettle();
    expect(find.text('30 min antes'), findsWidgets);
    await t.tap(find.byKey(const Key('aviso-recordatorios')));
    await t.pumpAndSettle();
    expect(guardados.last['apagados'], ['recordatorios']);
    await t.ensureVisible(find.byKey(const Key('minutos-15')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('minutos-15')));
    await t.pumpAndSettle();
    expect(guardados.last['recordar_cita_min'], 15);
    expect(guardados.last['apagados'], ['recordatorios']); // no se pierde lo apagado antes
  });

  testWidgets('nueva cita: la cuenta de un profesional no elige con quién', (t) async {
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(hoy),
      'GET /tratamientos': (_) => ok({
        'tratamientos': [
          {'id': 1, 'nombre': 'Corte clásico', 'duracion_min': 30},
        ],
      }),
      'GET /citas/disponibilidad': (_) => ok({'dias': []}),
    });
    await abrir(t, red, conSesion());
    await t.tap(find.text('Nueva cita'));
    await t.pumpAndSettle();
    await t.tap(find.text('Corte clásico'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('paso-quien')), findsNothing);
    expect(find.text('Nueva cita · paso 2 de 3'), findsOneWidget);
  });

  testWidgets('Llegó se marca con un toque y No vino espera la tolerancia', (t) async {
    fijarReloj(10, 5); // la cita es a las 10:00 y la tolerancia de la barbería es de 10 min
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(hoy),
      'POST /citas/1/llego': (_) => ok({
        'agenda': agendaJson([
          {...conBarbero(citaJson(1, 'programada', 'Rosa Paz')), 'llegada_en': '2026-11-09T10:05:00-05:00'},
        ]),
      }),
    });
    await abrir(t, red, conSesion());
    final noVino = t.widget<OutlinedButton>(find.byKey(const Key('no-vino')));
    expect(noVino.onPressed, isNull);
    expect(find.text('No vino (10:10)'), findsOneWidget);
    await t.tap(find.byKey(const Key('llego')));
    await t.pumpAndSettle();
    expect(red.llamadas, contains('POST /citas/1/llego'));
    expect(find.byKey(const Key('llego-1')), findsOneWidget);
    expect(find.byKey(const Key('no-vino')), findsNothing); // ya está: solo queda Iniciar
  });

  testWidgets('Ya llegó: «Atendida» la cierra sin cronómetro', (t) async {
    fijarReloj(10, 5);
    final llegada = {...conBarbero(citaJson(1, 'programada', 'Rosa Paz')), 'llegada_en': '2026-11-09T10:01:00-05:00'};
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(agendaJson([llegada])),
      'POST /citas/1/terminar': (_) => ok({
        'agenda': agendaJson([
          {...llegada, 'estado': 'terminada', 'estado_texto': 'Terminada'},
        ]),
      }),
    });
    await abrir(t, red, conSesion());
    expect(find.byKey(const Key('no-vino')), findsNothing);
    expect(find.text('Iniciar'), findsOneWidget);
    await t.tap(find.byKey(const Key('atendida')));
    await t.pumpAndSettle();
    expect(red.llamadas, contains('POST /citas/1/terminar'));
    expect(find.byKey(const Key('atendida')), findsNothing);
  });

  testWidgets('«Me demoro» manda los minutos y ofrece avisar a los que esperan', (t) async {
    fijarReloj(10, 5);
    Object? cuerpo;
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(hoy),
      'POST /citas/1/demora': (o) {
        cuerpo = o.data;
        return ok({
          'agenda': hoy,
          'avisos': [
            {
              'cita_id': 1,
              'paciente': 'Rosa Paz',
              'inicio': '2026-11-09T10:00:00-05:00',
              'inicio_estimado': '2026-11-09T10:20:00-05:00',
              'retraso_min': 20,
              'whatsapp_url': 'https://wa.me/51987111222?text=hola',
            },
          ],
        });
      },
    });
    await abrir(t, red, conSesion());
    await t.tap(find.byKey(const Key('me-demoro')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('demora-15')));
    await t.pumpAndSettle();
    expect(cuerpo, {'minutos': 15});
    expect(find.byKey(const Key('aviso-demora-1')), findsOneWidget);
    expect(find.textContaining('(+20 min)'), findsOneWidget);
  });

  group('precio ofertable', () {
    Map<String, dynamic> conOferta() => {
      ...conBarbero(citaJson(5, 'por_aprobar', 'Rosa Paz')),
      'precio_referencia': 2000,
      'precio_ofrecido': 1800,
      'precio_acordado': null,
      'precio_texto': 'Ofrece S/ 18',
    };

    RedFalsa red(List<Object?> cuerpos) => RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(agendaJson([conOferta()], porAprobar: 1)),
      'GET /citas/por-aprobar': (_) => ok({
        'citas': [conOferta()],
      }),
      'POST /citas/5/aprobar': (o) {
        cuerpos.add(o.data);
        return ok({
          'cita_id': 5,
          'estado': 'programada',
          'whatsapp_url': 'https://wa.me/51987654321?text=S%2F%2018',
          'siguientes': [],
          'agenda': agendaJson([]),
        });
      },
    });

    Future<void> abrirPorConfirmar(WidgetTester t, RedFalsa r) async {
      instalarLanzador();
      await abrir(t, r, conSesion());
      await t.tap(find.byKey(const Key('por-confirmar')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('oferta-5')), findsOneWidget);
      await t.tap(find.text('Confirmar y avisar'));
      await t.pumpAndSettle();
      expect(find.text('Rosa Paz ofrece S/ 18'), findsOneWidget);
    }

    testWidgets('aceptar la oferta fija ese precio', (t) async {
      final cuerpos = <Object?>[];
      await abrirPorConfirmar(t, red(cuerpos));
      await t.tap(find.text('Aceptar S/ 18'));
      await t.pumpAndSettle();
      expect(cuerpos.single, {'precio_acordado': 18.0});
    });

    testWidgets('o se pone otro precio', (t) async {
      final cuerpos = <Object?>[];
      await abrirPorConfirmar(t, red(cuerpos));
      await t.tap(find.text('Poner otro precio'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('precio-final')), '22.50');
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(cuerpos.single, {'precio_acordado': 22.5});
    });
  });

  testWidgets('Mi mes muestra los indicadores y el mes anterior', (t) async {
    fijarReloj(10, 0);
    Map<String, dynamic> kpi(int citas) => {
      'citas': citas,
      'confirmacion_pct': 90,
      'inasistencia_pct': 5,
      'ocupacion_pct': 60,
      'respuesta_mediana_min': 12,
      'espera_mediana_min': null,
      'vuelven_pct': 40,
      'por_confirmar': 2,
    };
    final red = RedFalsa({
      'POST /auth/refresh': (_) => ok(tokens),
      'GET /negocio': (_) => ok(negocioJson()),
      'GET /agenda': (_) => ok(hoy),
      'GET /metricas': (_) => ok({'anio': 2026, 'mes': 11, 'actual': kpi(42), 'anterior': kpi(30)}),
    });
    await abrir(t, red, conSesion());
    await t.tap(find.text('Ajustes'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mi mes'));
    await t.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Mes anterior: 30'), findsOneWidget);
    expect(find.text('2 reservas esperan tu respuesta.'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Espera en la barbería'), 200);
    expect(find.text('Espera en la barbería'), findsOneWidget);
  });

  testWidgets('con el bloqueo activo pide la huella al abrir', (t) async {
    final autenticador = AutenticadorFalso();
    final almacen = conSesion()..datos[claveBloqueoActivo] = '1';
    final red = RedFalsa({'POST /auth/refresh': (_) => ok(tokens), 'GET /agenda': (_) => ok(hoy)});
    await abrir(t, red, almacen, autenticador: autenticador);
    expect(find.byKey(const Key('capa-bloqueo')), findsOneWidget);
    autenticador.respuesta = false;
    await t.tap(find.text('Desbloquear'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('capa-bloqueo')), findsOneWidget);
    autenticador.respuesta = true;
    await t.tap(find.text('Desbloquear'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('capa-bloqueo')), findsNothing);
    expect(find.text('Rosa Paz'), findsOneWidget);
  });

  group('idempotencia', () {
    test('cada cambio lleva su Idempotency-Key y el reintento por red usa la misma', () async {
      final claves = <String?>[];
      var intentos = 0;
      final red = RedFalsa({
        'POST /citas/1/extender': (o) {
          claves.add(o.headers['Idempotency-Key'] as String?);
          intentos++;
          return intentos == 1 ? null : ok({'ok': true}); // la primera vez se corta la señal
        },
        'GET /agenda': (o) {
          claves.add(o.headers['Idempotency-Key'] as String?);
          return ok({});
        },
      });
      final api = ApiCliente(AlmacenMemoria(), red);
      expect(await api.post('/citas/1/extender', {'minutos': 10}), {'ok': true});
      expect(claves, hasLength(2));
      expect(claves.first, isNotNull);
      expect(claves.first, claves.last);
      await api.get('/agenda');
      expect(claves.last, isNull); // las lecturas no la necesitan
    });

    test('dos cambios distintos llevan claves distintas', () async {
      final claves = <String>[];
      final red = RedFalsa({
        'POST /citas/1/iniciar': (o) {
          claves.add(o.headers['Idempotency-Key'] as String);
          return ok({});
        },
      });
      final api = ApiCliente(AlmacenMemoria(), red);
      await api.post('/citas/1/iniciar');
      await api.post('/citas/1/iniciar');
      expect(claves[0], isNot(claves[1]));
      expect(claves[0], hasLength(32));
    });

    test('sin señal dos veces seguidas, el error llega al doctor', () async {
      final red = RedFalsa({'POST /citas/1/iniciar': (_) => null});
      final api = ApiCliente(AlmacenMemoria(), red);
      await expectLater(
        api.post('/citas/1/iniciar'),
        throwsA(isA<ApiError>().having((e) => e.sinConexion, 'sin', true)),
      );
      expect(red.llamadas.where((l) => l == 'POST /citas/1/iniciar'), hasLength(2));
    });
  });

  test('DioException no se escapa como tal', () {
    expect(ApiCliente.errorDe(DioException(requestOptions: RequestOptions())).sinConexion, isTrue);
  });
}
