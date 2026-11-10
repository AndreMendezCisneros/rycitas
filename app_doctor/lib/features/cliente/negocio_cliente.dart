import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../citas/selector_hora.dart';
import 'datos_cliente.dart';
import 'widgets_cliente.dart';

/// Ficha del lugar: tarjeta de sellos, cupones y servicios para reservar.
class NegocioClientePantalla extends ConsumerWidget {
  const NegocioClientePantalla({super.key, required this.slug});

  final String slug;

  Future<void> _silenciar(BuildContext context, WidgetRef ref, bool silenciar) async {
    try {
      await ref.read(apiClienteProvider).post('/negocios/$slug/silenciar?silenciar=$silenciar');
      ref.invalidate(negocioClienteProvider(slug));
      if (context.mounted) {
        avisar(context, silenciar ? 'Ya no recibirás sus promociones.' : 'Volverás a recibir sus promociones.');
      }
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(negocioClienteProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: Text(datos.value?['nombre'] as String? ?? ''),
        actions: [
          if (datos.value?['es_cliente'] == true)
            PopupMenuButton<bool>(
              onSelected: (v) => _silenciar(context, ref, v),
              itemBuilder: (_) => [
                datos.value?['silenciado'] == true
                    ? const PopupMenuItem(value: false, child: Text('Recibir sus promociones'))
                    : const PopupMenuItem(value: true, child: Text('No recibir sus promociones')),
              ],
            ),
        ],
      ),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(negocioClienteProvider(slug))),
        data: (n) {
          final servicios = lista(n['motivos']);
          final cupones = lista(n['cupones']);
          final tarjeta = n['tarjeta'] as Json?;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  FotoNegocio(negocio: n, lado: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n['nombre'] as String, style: Theme.of(context).textTheme.titleLarge),
                        Text('${n['rubro_nombre']}'),
                        Text(
                          n['direccion'] as String,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if ((n['mapa_url'] as String? ?? '').isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Cómo llegar'),
                      onPressed: () => abrirEnlace(context, n['mapa_url'] as String),
                    ),
                  if ((n['whatsapp'] as String? ?? '').isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                      onPressed: () => abrirWhatsapp(context, 'https://wa.me/${n['whatsapp']}'),
                    ),
                ],
              ),
              if (tarjeta != null && tarjeta['activa'] == true) ...[
                const SizedBox(height: 12),
                TarjetaSellos(tarjeta: tarjeta),
              ],
              if (cupones.isNotEmpty) ...[
                const TituloGrupo('Tus cupones'),
                for (final c in cupones) TarjetaCupon(cupon: c),
              ],
              TituloGrupo('Reserva'),
              if (n['acepta_reservas'] != true)
                const AvisoSuave(
                  icono: Icons.event_busy_rounded,
                  texto: 'Este lugar no está tomando reservas en línea por ahora.',
                )
              else
                for (final s in servicios)
                  Card(
                    key: Key('servicio-${s['slug']}'),
                    child: ListTile(
                      title: Text(s['nombre'] as String),
                      subtitle: Text(
                        [
                          '${s['duracion_min']} min',
                          if (s['precio_desde'] != null) 'desde S/ ${s['precio_desde']}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/cliente/negocio/$slug/reservar/${s['slug']}'),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Reserva desde la app: (con quién) → hora → confirmar con cupón. Queda «por confirmar», como en la web.
class ReservarClientePantalla extends ConsumerStatefulWidget {
  const ReservarClientePantalla({super.key, required this.slug, required this.motivo});

  final String slug;
  final String motivo;

  @override
  ConsumerState<ReservarClientePantalla> createState() => _ReservarClienteState();
}

class _ReservarClienteState extends ConsumerState<ReservarClientePantalla> {
  bool _quienElegido = false;
  int? _profesional;
  String? _hora;
  int? _cupon;
  bool _enviando = false;
  Json? _hecha;

  List<Json> _profesionales(Json n) => lista(n['profesionales']).where((p) {
    final hace = p['servicios'] as List?;
    return hace == null || hace.contains(widget.motivo);
  }).toList();

  Future<void> _reservar(Json negocio) async {
    setState(() => _enviando = true);
    try {
      final r = await ref.read(apiClienteProvider).post('/negocios/${widget.slug}/reservas', {
        'motivo': widget.motivo,
        'inicio': _hora,
        'profesional': ?_profesional,
        'cupon': ?_cupon,
      });
      refrescarCliente(ref);
      ref.invalidate(negocioClienteProvider(widget.slug));
      if (mounted) setState(() => _hecha = r);
    } on ApiError catch (e) {
      if (!mounted) return;
      avisar(context, e.mensaje);
      // Otro tomó la hora o el número ya tiene una cita a esa hora: se vuelve a elegir.
      if (e.status == 409) setState(() => _hora = null);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(negocioClienteProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(title: const Text('Reservar')),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) =>
            ErrorConReintento(error: e, alReintentar: () => ref.invalidate(negocioClienteProvider(widget.slug))),
        data: (n) {
          if (_hecha != null) return _Lista(reserva: _hecha!, negocio: n);
          final servicio = lista(n['motivos']).firstWhere((s) => s['slug'] == widget.motivo, orElse: () => {});
          final pros = _profesionales(n);
          final elegir = (n['opciones'] as Json?)?['elegir_profesional'] == true && pros.length > 1;
          if (elegir && !_quienElegido) return _pasoQuien(pros);
          if (_hora == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${servicio['nombre'] ?? ''}: elige el día y la hora',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: SelectorHora(
                    key: const Key('paso-hora'),
                    fuente: horasClienteProvider((slug: widget.slug, motivo: widget.motivo, profesional: _profesional)),
                    alElegir: (h) => setState(() => _hora = h),
                  ),
                ),
              ],
            );
          }
          return _pasoConfirmar(n, servicio, pros);
        },
      ),
    );
  }

  Widget _pasoQuien(List<Json> pros) {
    void elegir(int? id) => setState(() {
      _profesional = id;
      _quienElegido = true;
    });
    return ListView(
      key: const Key('paso-quien'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('¿Con quién?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const Key('quien-cualquiera'),
            leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
            title: const Text('Con quien tenga la hora más cercana'),
            onTap: () => elegir(null),
          ),
        ),
        for (final p in pros)
          Card(
            child: ListTile(
              key: Key('quien-${p['id']}'),
              leading: Avatar(p['nombre'] as String),
              title: Text(p['nombre'] as String),
              subtitle: (p['detalle'] as String? ?? '').isEmpty ? null : Text(p['detalle'] as String),
              onTap: () => elegir(p['id'] as int),
            ),
          ),
      ],
    );
  }

  Widget _pasoConfirmar(Json n, Json servicio, List<Json> pros) {
    final cupones = lista(n['cupones']).where((c) => c['servicio_slug'] == null || c['servicio_slug'] == widget.motivo);
    final profesional = pros.where((p) => p['id'] == _profesional).firstOrNull;
    return ListView(
      key: const Key('paso-confirmar'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n['nombre'] as String, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('${servicio['nombre']} · ${servicio['duracion_min']} min'),
                Text(Fechas.diaHora(_hora!)),
                if (profesional != null) Text('Con ${profesional['nombre']}'),
                TextButton(onPressed: () => setState(() => _hora = null), child: const Text('Cambiar la hora')),
              ],
            ),
          ),
        ),
        if (cupones.isNotEmpty) ...[
          const TituloGrupo('¿Usas un cupón?'),
          RadioGroup<int?>(
            groupValue: _cupon,
            onChanged: (v) => setState(() => _cupon = v),
            child: Column(
              children: [
                const RadioListTile<int?>(value: null, title: Text('Sin cupón')),
                for (final c in cupones)
                  RadioListTile<int?>(
                    key: Key('usar-cupon-${c['codigo']}'),
                    value: c['id'] as int,
                    title: Text(c['titulo'] as String),
                    subtitle: Text('${c['descuento']} · código ${c['codigo']}'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${n['nombre']} confirmará tu reserva y te escribirá por WhatsApp.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('confirmar-reserva'),
          onPressed: _enviando ? null : () => _reservar(n),
          child: Text(_enviando ? 'Reservando…' : 'Reservar'),
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.reserva, required this.negocio});

  final Json reserva;
  final Json negocio;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final cupon = reserva['cupon'] as Json?;
    return ListView(
      key: const Key('reserva-hecha'),
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.check_circle_rounded, size: 72, color: esquema.primary),
        const SizedBox(height: 12),
        Text('¡Reserva enviada!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${reserva['tratamiento']} · ${Fechas.diaHora(reserva['inicio'] as String)}\n'
          '${negocio['nombre']} la confirmará y te escribirá por WhatsApp.',
          textAlign: TextAlign.center,
        ),
        if (cupon != null) ...[
          const SizedBox(height: 8),
          Text('Con tu cupón ${cupon['codigo']} (${cupon['descuento']}).', textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: () => context.go('/cliente/citas'), child: const Text('Ver mis citas')),
        TextButton(onPressed: () => context.go('/cliente'), child: const Text('Volver al inicio')),
      ],
    );
  }
}
