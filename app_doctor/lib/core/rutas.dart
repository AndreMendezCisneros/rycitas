import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../features/configuracion/turnos_pantalla.dart';
import '../features/fidelizacion/fidelizacion_pantallas.dart';
import '../features/metricas/metricas_pantalla.dart';
import '../features/pacientes/pacientes_pantalla.dart';
import '../features/recordatorios/recordatorios_pantalla.dart';
import 'modo.dart';
import 'negocio.dart';
import 'push.dart';

final rutasProvider = Provider<GoRouter>((ref) {
  // Cualquier cambio de modo o de sesión vuelve a evaluar a qué pantalla corresponde ir.
  final cambios = ValueNotifier<int>(0);
  ref.onDispose(cambios.dispose);
  void alCambiar() {
    cambios.value++;
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
      GoRoute(path: '/login', builder: (_, _) => const LoginPantalla()),
      GoRoute(path: '/bienvenida', builder: (_, _) => const BienvenidaPantalla()),
      GoRoute(path: '/cliente/entrar', builder: (_, _) => const RegistroClientePantalla()),
      // Modo cliente («Quiero reservar»).
      StatefulShellRoute.indexedStack(
        builder: (_, _, navegacion) => NavegacionCliente(navegacion: navegacion),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/cliente', builder: (_, _) => const InicioClientePantalla())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/cliente/citas', builder: (_, _) => const MisCitasPantalla())],
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
        builder: (_, estado) => NegocioClientePantalla(slug: estado.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/cliente/negocio/:slug/reservar/:motivo',
        builder: (_, estado) =>
            ReservarClientePantalla(slug: estado.pathParameters['slug']!, motivo: estado.pathParameters['motivo']!),
      ),
      StatefulShellRoute.indexedStack(
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
      GoRoute(path: '/nueva-cita', builder: (_, _) => const NuevaCitaPantalla()),
      GoRoute(path: '/por-aprobar', builder: (_, _) => const PorAprobarPantalla()),
      GoRoute(path: '/recordatorios', builder: (_, _) => const RecordatoriosPantalla()),
      GoRoute(
        path: '/pacientes/:id',
        builder: (_, estado) => PacienteDetallePantalla(id: int.parse(estado.pathParameters['id']!)),
      ),
      GoRoute(path: '/ajustes/horario', builder: (_, _) => const HorarioPantalla()),
      GoRoute(path: '/ajustes/turnos', builder: (_, _) => const TurnosPantalla()),
      GoRoute(path: '/ajustes/avisos', builder: (_, _) => const AvisosPantalla()),
      GoRoute(path: '/ajustes/bloqueos', builder: (_, _) => const BloqueosPantalla()),
      GoRoute(path: '/ajustes/tratamientos', builder: (_, _) => const TratamientosPantalla()),
      GoRoute(path: '/mi-mes', builder: (_, _) => const MetricasPantalla()),
      GoRoute(path: '/ajustes/fidelidad', builder: (_, _) => const FidelidadPantalla()),
      GoRoute(path: '/ajustes/cupones', builder: (_, _) => const CuponesPantalla()),
      GoRoute(path: '/ajustes/campanas', builder: (_, _) => const CampanasPantalla()),
    ],
  );
  ref.onDispose(router.dispose);
  ref.listen(destinoPushProvider, (_, destino) {
    if (destino == null) return;
    final modo = ref.read(modoProvider);
    final activa = modo == ModoApp.cliente
        ? ref.read(sesionClienteProvider) == EstadoSesion.activa
        : ref.read(sesionProvider) == EstadoSesion.activa;
    if (!activa) return;
    // Las pestañas principales se abren, no se apilan encima.
    const pestanas = {'/', '/cliente/beneficios', '/cliente/citas'};
    pestanas.contains(destino) ? router.go(destino) : router.push(destino);
    ref.read(destinoPushProvider.notifier).state = null;
  });
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
    Widget conInsignia(IconData icono) =>
        Badge(isLabelVisible: pendientes > 0, label: Text('$pendientes'), child: Icon(icono));
    return Scaffold(
      body: navegacion,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, -2))],
        ),
        child: NavigationBar(
          selectedIndex: navegacion.currentIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            navegacion.goBranch(i, initialLocation: i == navegacion.currentIndex);
          },
          destinations: [
            NavigationDestination(
              icon: conInsignia(Icons.today_outlined),
              selectedIcon: conInsignia(Icons.today_rounded),
              label: 'Hoy',
            ),
            const NavigationDestination(
              icon: Icon(Icons.date_range),
              selectedIcon: Icon(Icons.date_range_rounded),
              label: 'Semana',
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: Vocabulario.may(voc.clientes),
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
