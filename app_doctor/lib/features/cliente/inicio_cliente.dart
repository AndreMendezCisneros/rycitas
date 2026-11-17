import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/modo.dart';
import '../../shared/comunes.dart';
import '../../shared/diseno/barra_navegacion.dart';
import '../../shared/diseno/movimiento.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import 'citas_beneficios.dart';
import 'datos_cliente.dart';
import 'gamificacion.dart';
import 'lugares_hoja.dart';
import 'mascota.dart';
import 'sesion_cliente.dart';
import 'widgets_cliente.dart';
import '../../shared/diseno/tonos.dart';
import '../../core/apariencia.dart';

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

  void _abrirRubi(String nombre) {
    mostrarLugaresParaReservar(
      context,
      encabezado: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Rubi(tam: 64, expresion: ExpresionRubi.celebra),
            const SizedBox(width: 10),
            Expanded(
              child: GloboRubi(texto: 'Estos son los lugares donde puedes reservar, $nombre. ¿Cuál te provoca?'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yo = ref.watch(yoProvider).value;
    final nombre = (yo?['nombre'] as String? ?? '').split(' ').first;
    final proxima = lista(ref.watch(misCitasProvider).valueOrNull?['proximas']).firstOrNull;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: FondoManchas(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async => refrescarCliente(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre.isEmpty ? '¡Hola!' : '¡Hola, $nombre!', style: textos.headlineMedium),
                          const SizedBox(height: 8),
                          GloboRubi(texto: saludoRubi(nombre.isEmpty ? 'tú' : nombre, Fechas.ahora())),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        Rubi(tam: 92, alTocar: () => _abrirRubi(nombre.isEmpty ? 'amiga' : nombre)),
                        Text(
                          'Tócame',
                          style: textos.labelSmall?.copyWith(color: context.tonos.acento, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (proxima != null) ...[ProximaCitaTarjeta(cita: proxima), const SizedBox(height: 16)],
                const TarjetaProgreso(),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('buscar-negocio'),
                  controller: _buscar,
                  onChanged: _alEscribir,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Busca por nombre o distrito',
                    fillColor: context.tonos.superficie,
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buscando
                      ? _Resultados(key: ValueKey('$_q|$_rubro'), q: _q, rubro: _rubro)
                      : const _MisLugares(key: ValueKey('mios')),
                ),
              ],
            ),
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
          avatar: Icon(iconoRubro(rubros[i]['clave'] as String), size: 18, color: context.tonos.acento),
          showCheckmark: false,
          label: Text(rubros[i]['nombre'] as String),
          selected: rubros[i]['clave'] == elegido,
          onSelected: (_) => alElegir(rubros[i]['clave'] as String),
        ),
      ),
    );
  }
}

class _MisLugares extends ConsumerWidget {
  const _MisLugares({super.key});

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
                texto:
                    'Lo que reservas aquí ya aparece en «Mis citas». Para ver también las citas que hiciste por '
                    'WhatsApp o en la web, y tus sellos y cupones, pega el enlace que te mandó el negocio al confirmar.',
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
            texto: 'Aquí aparecerán los lugares donde reservas con este WhatsApp. Toca a Rubí o busca uno arriba.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloGrupo('Tus lugares'),
            for (final (i, n) in negocios.indexed)
              AparecerEnCascada(
                indice: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TarjetaNegocio(negocio: n, conProgreso: true),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados({super.key, required this.q, required this.rubro});

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
          children: [
            for (final (i, n) in negocios.indexed)
              AparecerEnCascada(
                indice: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TarjetaNegocio(negocio: n),
                ),
              ),
          ],
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

  Future<void> _cambiarPromociones(BuildContext context, WidgetRef ref, String nombre, bool acepta) async {
    try {
      await ref.read(apiClienteProvider).put('/yo', {'nombre': nombre, 'acepta_publicidad': acepta});
      ref.invalidate(yoProvider);
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  Future<void> _cambiarClave(BuildContext context, WidgetRef ref) async {
    final actual = TextEditingController();
    final nueva = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('clave-actual'),
              controller: actual,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña actual',
                helperText: 'Si tu cuenta aún no tenía, déjala vacía.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('clave-nueva'),
              controller: nueva,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 8 caracteres.'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('guardar-clave'),
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClienteProvider).put('/yo/clave', {'actual': actual.text, 'nueva': nueva.text});
      if (context.mounted) avisar(context, 'Contraseña actualizada');
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  /// Derecho de cancelación (y requisito de Google Play): la cuenta se borra desde la propia app.
  Future<void> _eliminarCuenta(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      '¿Eliminar tu cuenta?',
      'Se borran tu cuenta, tu correo y tus avisos. Para borrar tus citas de un lugar, pídeselo a ese lugar. '
          'No se puede deshacer.',
      accion: 'Eliminar',
    );
    if (!ok) return;
    try {
      await ref.read(apiClienteProvider).delete('/yo');
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
      return;
    }
    await _salir(ref, a: ModoApp.ninguno);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yo = ref.watch(yoProvider);
    return Scaffold(
      backgroundColor: context.tonos.fondo,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: yo.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(yoProvider)),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: Paleta.degradado, borderRadius: BorderRadius.circular(26)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      (d['nombre'] as String).characters.first.toUpperCase(),
                      style: TextStyle(color: context.tonos.acento, fontWeight: FontWeight.w800, fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['nombre'] as String,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                        Text('${d['correo']}', style: const TextStyle(color: Colors.white70)),
                        Text('WhatsApp ${d['celular']}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TarjetaProgreso(),
            const SizedBox(height: 12),
            TarjetaInvitar(codigo: d['codigo_referido'] as String, invitados: d['invitados'] as int? ?? 0),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('cliente-cambiar-clave'),
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Cambiar contraseña'),
                    onTap: () => _cambiarClave(context, ref),
                  ),
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
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const SelectorTema(),
                  SwitchListTile(
                    key: const Key('cliente-promociones'),
                    title: const Text('Recibir promociones'),
                    subtitle: const Text('De los lugares donde reservas. Opcional.'),
                    value: d['acepta_publicidad'] == true,
                    onChanged: (v) => _cambiarPromociones(context, ref, d['nombre'] as String, v),
                  ),
                  ListTile(
                    key: const Key('cliente-eliminar-cuenta'),
                    leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                    title: const Text('Eliminar mi cuenta'),
                    subtitle: const Text('Borra tu cuenta de la app. Tus citas las guarda cada lugar.'),
                    onTap: () => _eliminarCuenta(context, ref),
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
      bottomNavigationBar: BarraFlotante(
        indice: navegacion.currentIndex,
        alElegir: (i) => navegacion.goBranch(i, initialLocation: i == navegacion.currentIndex),
        destinos: const [
          DestinoBarra(icono: Icons.home_outlined, iconoActivo: Icons.home_rounded, texto: 'Inicio'),
          DestinoBarra(icono: Icons.event_note_outlined, iconoActivo: Icons.event_note_rounded, texto: 'Mis citas'),
          DestinoBarra(icono: Icons.loyalty_outlined, iconoActivo: Icons.loyalty_rounded, texto: 'Beneficios'),
          DestinoBarra(icono: Icons.person_outline, iconoActivo: Icons.person_rounded, texto: 'Perfil'),
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
