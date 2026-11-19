import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/agenda/agenda_controlador.dart';
import '../features/agenda/hoy_pantalla.dart';
import '../features/agenda/semana_pantalla.dart';
import '../features/auth/login_pantalla.dart';
import '../features/auth/sesion.dart';
import '../features/cliente/citas_beneficios.dart';
import '../features/cliente/entrada_pantallas.dart';
import '../features/cliente/inicio_cliente.dart';
import '../features/cliente/negocio_cliente.dart';
import '../features/cliente/sesion_cliente.dart';
import '../features/citas/nueva_cita_pantalla.dart';
import '../features/citas/por_aprobar_pantalla.dart';
import '../features/configuracion/ajustes_pantalla.dart';
import '../features/configuracion/avisos_pantalla.dart';
import '../features/configuracion/bloqueos_pantalla.dart';
import '../features/configuracion/horario_pantalla.dart';
import '../features/configuracion/tratamientos_pantalla.dart';
import '../features/configuracion/reglas_pantalla.dart';
import '../features/configuracion/turnos_pantalla.dart';
import '../features/fidelizacion/fidelizacion_pantallas.dart';
import '../features/metricas/metricas_pantalla.dart';
import '../features/pacientes/pacientes_pantalla.dart';
import '../features/recordatorios/recordatorios_pantalla.dart';
import '../shared/diseno/barra_navegacion.dart';
import '../shared/diseno/movimiento.dart';
import 'modo.dart';
import 'negocio.dart';
import 'push.dart';

final rutasProvider = Provider<GoRouter>((ref) {
  // Cualquier cambio de modo o de sesión vuelve a evaluar a qué pantalla corresponde ir.
  final cambios = ValueNotifier<int>(0);
  ref.onDispose(cambios.dispose);
  // Se declara antes que el router; se asigna al final (un aviso puede llegar antes de que la sesión esté activa).
  void Function() aplicarDestinoPendiente = () {};
  var vivo = true;
  ref.onDispose(() => vivo = false);

  void alCambiar() {
    cambios.value++;
    Future.microtask(() {
      if (vivo) aplicarDestinoPendiente();
    });
    final modo = ref.read(modoProvider);
    if (modo == ModoApp.negocio && ref.read(sesionProvider) == EstadoSesion.activa) {
      ref.read(pushClienteProvider).detener();
      ref.read(pushProvider).iniciar();
    } else if (modo == ModoApp.cliente && ref.read(sesionClienteProvider) == EstadoSesion.activa) {
      ref.read(pushProvider).detener();
      ref.read(pushClienteProvider).iniciar();
    }
  }

  ref.listen(modoProvider, (_, _) => alCambiar());
  ref.listen(sesionProvider, (_, _) => alCambiar());
  ref.listen(sesionClienteProvider, (_, _) => alCambiar());

  final router = GoRouter(
    initialLocation: '/hoy',
    refreshListenable: cambios,
    // Una ruta desconocida (p. ej. de un aviso viejo) nunca deja una pantalla rota: vuelve al inicio del modo.
    onException: (_, _, router) => router.go(ref.read(modoProvider) == ModoApp.cliente ? '/cliente' : '/hoy'),
    redirect: (_, estadoRuta) {
      final ruta = estadoRuta.matchedLocation;
      final enCarga = ruta == '/cargando';
      final cargando = enCarga ? null : '/cargando';
      switch (ref.read(modoProvider)) {
        case ModoApp.cargando:
          return cargando;
        case ModoApp.ninguno:
          return ruta == '/bienvenida' ? null : '/bienvenida';
        case ModoApp.cliente:
          final enEntrada = ruta == '/cliente/entrar';
          return switch (ref.read(sesionClienteProvider)) {
            EstadoSesion.cargando => cargando,
            EstadoSesion.cerrada => enEntrada ? null : '/cliente/entrar',
            EstadoSesion.activa => enEntrada || !ruta.startsWith('/cliente') ? '/cliente' : null,
          };
        case ModoApp.negocio:
          final enLogin = ruta == '/login';
          final ajena = ruta.startsWith('/cliente') || ruta == '/bienvenida';
          return switch (ref.read(sesionProvider)) {
            EstadoSesion.cargando => cargando,
            EstadoSesion.cerrada => enLogin ? null : '/login',
            EstadoSesion.activa => enLogin || enCarga || ajena ? '/hoy' : null,
          };
      }
    },
    routes: [
      GoRoute(
        path: '/cargando',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', pageBuilder: (_, estado) => paginaConTransicion(estado, const LoginPantalla())),
      GoRoute(path: '/bienvenida', pageBuilder: (_, estado) => paginaConTransicion(estado, const BienvenidaPantalla())),
      GoRoute(
        path: '/cliente/entrar',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const RegistroClientePantalla()),
      ),
      // Modo cliente («Quiero reservar»).
      StatefulShellRoute(
        navigatorContainerBuilder: _pestanas,
        builder: (_, _, navegacion) => NavegacionCliente(navegacion: navegacion),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/cliente', builder: (_, _) => const InicioClientePantalla())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cliente/citas',
                builder: (_, estado) => MisCitasPantalla(citaInicial: estado.uri.queryParameters['cita']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/cliente/beneficios', builder: (_, _) => const BeneficiosPantalla())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/cliente/perfil', builder: (_, _) => const PerfilClientePantalla())],
          ),
        ],
      ),
      GoRoute(
        path: '/cliente/negocio/:slug',
        pageBuilder: (_, estado) => paginaConTransicion(
          estado,
          NegocioClientePantalla(slug: estado.pathParameters['slug']!, fecha: estado.uri.queryParameters['fecha']),
        ),
      ),
      GoRoute(
        path: '/cliente/negocio/:slug/reservar/:motivo',
        pageBuilder: (_, estado) => paginaConTransicion(
          estado,
          ReservarClientePantalla(
            slug: estado.pathParameters['slug']!,
            motivo: estado.pathParameters['motivo']!,
            fecha: estado.uri.queryParameters['fecha'],
          ),
        ),
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: _pestanas,
        builder: (_, _, navegacion) => _Navegacion(navegacion: navegacion),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/hoy', builder: (_, _) => const HoyPantalla())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/semana', builder: (_, _) => const SemanaPantalla())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/pacientes', builder: (_, _) => const PacientesPantalla())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/ajustes', builder: (_, _) => const AjustesPantalla())],
          ),
        ],
      ),
      GoRoute(path: '/nueva-cita', pageBuilder: (_, estado) => paginaConTransicion(estado, const NuevaCitaPantalla())),
      GoRoute(
        path: '/por-aprobar',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const PorAprobarPantalla()),
      ),
      GoRoute(
        path: '/recordatorios',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const RecordatoriosPantalla()),
      ),
      GoRoute(
        path: '/pacientes/:id',
        pageBuilder: (_, estado) =>
            paginaConTransicion(estado, PacienteDetallePantalla(id: int.parse(estado.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/ajustes/horario',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const HorarioPantalla()),
      ),
      GoRoute(path: '/ajustes/turnos', pageBuilder: (_, estado) => paginaConTransicion(estado, const TurnosPantalla())),
      GoRoute(path: '/ajustes/reglas', pageBuilder: (_, estado) => paginaConTransicion(estado, const ReglasPantalla())),
      GoRoute(path: '/ajustes/avisos', pageBuilder: (_, estado) => paginaConTransicion(estado, const AvisosPantalla())),
      GoRoute(
        path: '/ajustes/bloqueos',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const BloqueosPantalla()),
      ),
      GoRoute(
        path: '/ajustes/tratamientos',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const TratamientosPantalla()),
      ),
      GoRoute(path: '/mi-mes', pageBuilder: (_, estado) => paginaConTransicion(estado, const MetricasPantalla())),
      GoRoute(
        path: '/ajustes/fidelidad',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const FidelidadPantalla()),
      ),
      GoRoute(
        path: '/ajustes/cupones',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const CuponesPantalla()),
      ),
      GoRoute(
        path: '/ajustes/campanas',
        pageBuilder: (_, estado) => paginaConTransicion(estado, const CampanasPantalla()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  aplicarDestinoPendiente = () {
    final destino = ref.read(destinoPushProvider);
    if (destino == null) return;
    final modo = ref.read(modoProvider);
    final activa = modo == ModoApp.cliente
        ? ref.read(sesionClienteProvider) == EstadoSesion.activa
        : ref.read(sesionProvider) == EstadoSesion.activa;
    if (!activa) return; // queda guardado hasta que la sesión esté activa
    ref.read(destinoPushProvider.notifier).state = null;
    // Las pestañas principales se abren, no se apilan encima.
    const pestanas = {'/hoy', '/semana', '/cliente', '/cliente/citas', '/cliente/beneficios'};
    pestanas.contains(Uri.parse(destino).path) ? router.go(destino) : router.push(destino);
  };
  ref.listen(destinoPushProvider, (_, _) => aplicarDestinoPendiente());
  return router;
});

class _Navegacion extends ConsumerWidget {
  const _Navegacion({required this.navegacion});

  final StatefulNavigationShell navegacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voc = ref.watch(vocProvider);
    // Insignia en «Hoy» con las reservas web que esperan respuesta.
    final pendientes = ref.watch(agendaProvider.select((e) => e.value?.agenda.porAprobar ?? 0));
    return Scaffold(
      body: navegacion,
      bottomNavigationBar: BarraFlotante(
        indice: navegacion.currentIndex,
        alElegir: (i) => navegacion.goBranch(i, initialLocation: i == navegacion.currentIndex),
        destinos: [
          DestinoBarra(
            icono: Icons.today_outlined,
            iconoActivo: Icons.today_rounded,
            texto: 'Hoy',
            insignia: pendientes,
          ),
          const DestinoBarra(
            icono: Icons.calendar_month_outlined,
            iconoActivo: Icons.calendar_month_rounded,
            texto: 'Calendario',
          ),
          DestinoBarra(
            icono: Icons.people_outline_rounded,
            iconoActivo: Icons.people_rounded,
            texto: Vocabulario.may(voc.clientes),
          ),
          const DestinoBarra(icono: Icons.settings_outlined, iconoActivo: Icons.settings_rounded, texto: 'Ajustes'),
        ],
      ),
    );
  }
}

Widget _pestanas(BuildContext _, StatefulNavigationShell navegacion, List<Widget> hijos) =>
    PestanasAnimadas(indice: navegacion.currentIndex, hijos: hijos);
