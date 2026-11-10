import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/modo.dart';
import '../../shared/comunes.dart';
import 'datos_cliente.dart';
import 'sesion_cliente.dart';
import 'widgets_cliente.dart';

/// «Inicio» del cliente: sus lugares (vinculados por su WhatsApp) y el buscador.
class InicioClientePantalla extends ConsumerStatefulWidget {
  const InicioClientePantalla({super.key});

  @override
  ConsumerState<InicioClientePantalla> createState() => _InicioClienteState();
}

class _InicioClienteState extends ConsumerState<InicioClientePantalla> {
  final _buscar = TextEditingController();
  Timer? _espera;
  String _q = '';
  String _rubro = '';

  @override
  void dispose() {
    _espera?.cancel();
    _buscar.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () => setState(() => _q = texto.trim()));
  }

  bool get _buscando => _q.isNotEmpty || _rubro.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final yo = ref.watch(yoProvider).value;
    final nombre = (yo?['nombre'] as String? ?? '').split(' ').first;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => refrescarCliente(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(nombre.isEmpty ? '¡Hola!' : '¡Hola, $nombre!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '¿Dónde quieres reservar hoy?',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('buscar-negocio'),
                controller: _buscar,
                onChanged: _alEscribir,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Busca por nombre o distrito',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _buscar.clear();
                            setState(() => _q = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              _Rubros(elegido: _rubro, alElegir: (r) => setState(() => _rubro = r == _rubro ? '' : r)),
              const SizedBox(height: 16),
              if (_buscando) _Resultados(q: _q, rubro: _rubro) else const _MisLugares(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rubros extends ConsumerWidget {
  const _Rubros({required this.elegido, required this.alElegir});

  final String elegido;
  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rubros = lista(ref.watch(busquedaProvider((q: '', rubro: ''))).value?['rubros']);
    if (rubros.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rubros.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => FilterChip(
          label: Text(rubros[i]['nombre'] as String),
          selected: rubros[i]['clave'] == elegido,
          onSelected: (_) => alElegir(rubros[i]['clave'] as String),
        ),
      ),
    );
  }
}

class _MisLugares extends ConsumerWidget {
  const _MisLugares();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(misNegociosProvider);
    return datos.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Cargando()),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(misNegociosProvider)),
      data: (d) {
        final negocios = lista(d['negocios']);
        if (d['celular_verificado'] == false) {
          return Column(
            children: [
              const AvisoSuave(
                icono: Icons.verified_user_outlined,
                texto: 'Para ver tus citas, sellos y cupones, confirma que este WhatsApp es tuyo: pega el enlace de '
                    'una de tus citas, el que te mandó el negocio por WhatsApp.',
              ),
              FilledButton.tonalIcon(
                key: const Key('vincular-enlace'),
                onPressed: () => vincularConEnlace(context, ref),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Pegar el enlace de mi cita'),
              ),
            ],
          );
        }
        if (negocios.isEmpty) {
          return const AvisoSuave(
            icono: Icons.travel_explore_rounded,
            texto: 'Aquí aparecerán los lugares donde reservas con este WhatsApp. Busca uno arriba para empezar.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloGrupo('Tus lugares'),
            for (final n in negocios) TarjetaNegocio(negocio: n, conProgreso: true),
          ],
        );
      },
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados({required this.q, required this.rubro});

  final String q;
  final String rubro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(busquedaProvider((q: q, rubro: rubro)));
    return datos.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Cargando()),
      error: (e, _) =>
          ErrorConReintento(error: e, alReintentar: () => ref.invalidate(busquedaProvider((q: q, rubro: rubro)))),
      data: (d) {
        final negocios = lista(d['negocios']);
        if (negocios.isEmpty) {
          return const AvisoSuave(icono: Icons.search_off_rounded, texto: 'No encontramos lugares con esa búsqueda.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final n in negocios) TarjetaNegocio(negocio: n)],
        );
      },
    );
  }
}

/// «Perfil»: datos, código para invitar y salir.
class PerfilClientePantalla extends ConsumerWidget {
  const PerfilClientePantalla({super.key});

  Future<void> _salir(WidgetRef ref, {required ModoApp a}) async {
    await ref.read(sesionClienteProvider.notifier).cerrar();
    await ref.read(modoProvider.notifier).elegir(a);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yo = ref.watch(yoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: yo.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(yoProvider)),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Avatar(d['nombre'] as String),
                title: Text(d['nombre'] as String),
                subtitle: Text('${d['correo']}\nWhatsApp ${d['celular']}'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 8),
            TarjetaInvitar(codigo: d['codigo_referido'] as String, invitados: d['invitados'] as int? ?? 0),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Usar como negocio'),
                    subtitle: const Text('Si atiendes un negocio con RyCitas'),
                    onTap: () => _salir(ref, a: ModoApp.negocio),
                  ),
                  ListTile(
                    key: const Key('cliente-salir'),
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Cerrar sesión'),
                    onTap: () => _salir(ref, a: ModoApp.ninguno),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navegación inferior del modo cliente.
class NavegacionCliente extends StatelessWidget {
  const NavegacionCliente({super.key, required this.navegacion});

  final StatefulNavigationShell navegacion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navegacion,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navegacion.currentIndex,
        onDestinationSelected: (i) => navegacion.goBranch(i, initialLocation: i == navegacion.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Mis citas',
          ),
          NavigationDestination(
            icon: Icon(Icons.loyalty_outlined),
            selectedIcon: Icon(Icons.loyalty_rounded),
            label: 'Beneficios',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Extrae token y firma de un enlace `https://<negocio>/c/<token>/?v=<firma>` pegado desde WhatsApp.
({String token, String firma})? leerEnlaceDeCita(String texto) {
  final m = RegExp(r'/c/([A-Za-z0-9_-]+)/?(?:\?v=([0-9a-f]+))?').firstMatch(texto.trim());
  if (m == null) return null;
  return (token: m.group(1)!, firma: m.group(2) ?? '');
}

Future<void> vincularConEnlace(BuildContext context, WidgetRef ref) async {
  final campo = TextEditingController();
  final texto = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enlace de tu cita'),
      content: TextField(
        key: const Key('campo-enlace'),
        controller: campo,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'https://…/c/…'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, campo.text), child: const Text('Confirmar')),
      ],
    ),
  );
  campo.dispose();
  if (texto == null || !context.mounted) return;
  final enlace = leerEnlaceDeCita(texto);
  if (enlace == null) {
    avisar(context, 'Ese no parece el enlace de una cita.');
    return;
  }
  try {
    await ref.read(apiClienteProvider).post('/vincular', {'token': enlace.token, 'firma': enlace.firma});
    refrescarCliente(ref);
    if (context.mounted) avisar(context, 'Listo: confirmamos tu WhatsApp.');
  } on ApiError catch (e) {
    if (context.mounted) avisar(context, e.mensaje);
  }
}
