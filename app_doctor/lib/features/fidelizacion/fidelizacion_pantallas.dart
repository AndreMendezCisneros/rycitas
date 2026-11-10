import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../configuracion/tratamientos_pantalla.dart' show tratamientosProvider;

typedef Json = Map<String, dynamic>;

List<Json> _lista(Object? v) => (v as List? ?? const []).cast<Json>();

final fidelidadProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('/fidelidad'));
final cuponesProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('/cupones'));
final campanasProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiProvider).get('/campanas'));
final tarjetaPacienteProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.read(apiProvider).get('/pacientes/$id/tarjeta'),
);

/// «Tarjeta de sellos»: se activa, se elige cuántos sellos y el premio. Con el resumen del mes.
class FidelidadPantalla extends ConsumerStatefulWidget {
  const FidelidadPantalla({super.key});

  @override
  ConsumerState<FidelidadPantalla> createState() => _FidelidadState();
}

class _FidelidadState extends ConsumerState<FidelidadPantalla> {
  final _premio = TextEditingController();
  bool? _activa;
  int? _meta;
  bool? _puntualidad;
  bool _guardando = false;

  @override
  void dispose() {
    _premio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref.read(apiProvider).put('/fidelidad', {
        'activa': _activa,
        'meta': _meta,
        'premio': _premio.text,
        'puntualidad': _puntualidad,
      });
      ref.invalidate(fidelidadProvider);
      if (mounted) avisar(context, 'Guardado');
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(fidelidadProvider);
    final negocio = ref.watch(negocioActualProvider);
    final voc = ref.watch(vocProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjeta de sellos')),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(fidelidadProvider)),
        data: (d) {
          if (_activa == null) {
            _activa = d['activa'] as bool;
            _meta = d['meta'] as int;
            _puntualidad = d['puntualidad'] as bool;
            _premio.text = d['premio'] as String;
          }
          final r = d['resumen'] as Json;
          final editable = negocio.esGeneral;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TarjetaDato(valor: '${r['sellos_mes']}', etiqueta: 'sellos este mes', icono: Icons.verified),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TarjetaDato(
                      valor: '${r['premios_mes']}',
                      etiqueta: 'premios entregados',
                      icono: Icons.redeem,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TarjetaDato(
                      valor: '${r['con_app']}/${r['clientes']}',
                      etiqueta: '${voc.clientes} con la app',
                      icono: Icons.phone_iphone_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TarjetaDato(
                      valor: '${r['cupones_mes']}',
                      etiqueta: 'cupones usados',
                      icono: Icons.local_offer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        key: const Key('fidelidad-activa'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tarjeta de sellos activa'),
                        subtitle: Text('Un sello por cada visita terminada. Tus ${voc.clientes} la ven en su app.'),
                        value: _activa!,
                        onChanged: editable ? (v) => setState(() => _activa = v) : null,
                      ),
                      const SizedBox(height: 8),
                      Text('Sellos para el premio: $_meta'),
                      Slider(
                        key: const Key('fidelidad-meta'),
                        value: _meta!.toDouble(),
                        min: 3,
                        max: 12,
                        divisions: 9,
                        label: '$_meta',
                        onChanged: editable ? (v) => setState(() => _meta = v.round()) : null,
                      ),
                      TextField(
                        key: const Key('fidelidad-premio'),
                        controller: _premio,
                        enabled: editable,
                        decoration: const InputDecoration(labelText: 'Premio', hintText: 'Un corte gratis'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sello extra por llegar a tiempo'),
                        subtitle: const Text(
                          'Si marcas «Llegó» antes de su hora. Ayuda a que no se retrase la agenda.',
                        ),
                        value: _puntualidad!,
                        onChanged: editable ? (v) => setState(() => _puntualidad = v) : null,
                      ),
                      if (editable) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('fidelidad-guardar'),
                          onPressed: _guardando ? null : _guardar,
                          child: const Text('Guardar'),
                        ),
                      ] else
                        const Text('Solo la cuenta general cambia la tarjeta.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Niveles: Bronce, Plata (3 visitas en 6 meses) y Oro (6). Al terminar una cita se da el sello solo; '
                'cuando la tarjeta se llena, entrega el premio desde la ficha del ${voc.cliente}.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lista de cupones y creación.
class CuponesPantalla extends ConsumerWidget {
  const CuponesPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(cuponesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cupones')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nuevo-cupon'),
        onPressed: () => _crear(context, ref, _lista(datos.value?['segmentos'])),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo cupón'),
      ),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(cuponesProvider)),
        data: (d) {
          final cupones = _lista(d['cupones']);
          if (cupones.isEmpty) {
            return const Vacio(
              'Crea un cupón y llegará a la app de tus clientes. Luego envíalo como promoción.',
              icono: Icons.local_offer_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final c in cupones)
                Card(
                  key: Key('cupon-${c['codigo']}'),
                  child: ListTile(
                    title: Text('${c['titulo']} · ${c['descuento']}'),
                    subtitle: Text(
                      [
                        'Código ${c['codigo']}',
                        c['segmento_nombre'],
                        if (c['servicio'] != null) 'solo ${c['servicio']}',
                        'vence ${Fechas.diaCorto(c['vence_el'] as String)}',
                        '${c['usos']}${c['usos_max'] == null ? '' : '/${c['usos_max']}'} usos',
                      ].join(' · '),
                    ),
                    trailing: c['vigente'] == true
                        ? IconButton(
                            tooltip: 'Desactivar',
                            icon: const Icon(Icons.block_rounded),
                            onPressed: () async {
                              final ok = await confirmar(
                                context,
                                '¿Desactivar el cupón?',
                                'Ya no se podrá usar.',
                                accion: 'Desactivar',
                              );
                              if (!ok) return;
                              await ref.read(apiProvider).post('/cupones/${c['id']}/desactivar');
                              ref.invalidate(cuponesProvider);
                            },
                          )
                        : const Text('Inactivo'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crear(BuildContext context, WidgetRef ref, List<Json> segmentos) async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NuevoCupon(segmentos: segmentos),
    );
    if (creado == true) ref.invalidate(cuponesProvider);
  }
}

class _NuevoCupon extends ConsumerStatefulWidget {
  const _NuevoCupon({required this.segmentos});

  final List<Json> segmentos;

  @override
  ConsumerState<_NuevoCupon> createState() => _NuevoCuponState();
}

class _NuevoCuponState extends ConsumerState<_NuevoCupon> {
  final _titulo = TextEditingController();
  final _valor = TextEditingController(text: '20');
  final _codigo = TextEditingController();
  bool _porcentaje = true;
  String _segmento = 'todos';
  int? _servicio;
  int _dias = 30;
  String? _error;

  @override
  void dispose() {
    _titulo.dispose();
    _valor.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final valor = num.tryParse(_valor.text.replaceAll(',', '.'));
    if (valor == null) {
      setState(() => _error = 'Escribe el descuento.');
      return;
    }
    try {
      await ref.read(apiProvider).post('/cupones', {
        'titulo': _titulo.text,
        'codigo': _codigo.text,
        if (_porcentaje) 'descuento_pct': valor.round() else 'descuento_soles': valor,
        'segmento': _segmento,
        'tratamiento_id': ?_servicio,
        'vence_el': Fechas.fechaApi(Fechas.ahora().add(Duration(days: _dias))),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicios = ref.watch(tratamientosProvider).value ?? const [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Nuevo cupón', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('cupon-titulo'),
              controller: _titulo,
              decoration: const InputDecoration(labelText: '¿Qué ofreces?', hintText: '20 % en tu próxima limpieza'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('cupon-valor'),
                    controller: _valor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _porcentaje ? 'Descuento (%)' : 'Descuento (S/)'),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('%')),
                    ButtonSegment(value: false, label: Text('S/')),
                  ],
                  selected: {_porcentaje},
                  onSelectionChanged: (v) => setState(() => _porcentaje = v.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _segmento,
              decoration: const InputDecoration(labelText: '¿Para quién?'),
              items: [
                for (final s in widget.segmentos)
                  DropdownMenuItem(value: s['clave'] as String, child: Text('${s['nombre']} (${s['clientes']})')),
              ],
              onChanged: (v) => setState(() => _segmento = v ?? 'todos'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _servicio,
              decoration: const InputDecoration(labelText: 'Servicio'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Cualquiera')),
                for (final t in servicios) DropdownMenuItem(value: t.id, child: Text(t.nombre)),
              ],
              onChanged: (v) => setState(() => _servicio = v),
            ),
            const SizedBox(height: 12),
            Text('Vence en $_dias días'),
            Slider(
              value: _dias.toDouble(),
              min: 7,
              max: 90,
              divisions: 83,
              onChanged: (v) => setState(() => _dias = v.round()),
            ),
            TextField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código (opcional)',
                hintText: 'Se crea solo si lo dejas vacío',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(key: const Key('cupon-guardar'), onPressed: _guardar, child: const Text('Crear cupón')),
          ],
        ),
      ),
    );
  }
}

/// Enviar una promoción: push a quien tiene la app y WhatsApp (a mano, sin costo) para el resto.
class CampanasPantalla extends ConsumerStatefulWidget {
  const CampanasPantalla({super.key});

  @override
  ConsumerState<CampanasPantalla> createState() => _CampanasState();
}

class _CampanasState extends ConsumerState<CampanasPantalla> {
  final _titulo = TextEditingController();
  final _mensaje = TextEditingController();
  String _segmento = 'todos';
  int? _cupon;
  bool _enviando = false;
  List<Json>? _sinApp;
  final _enviados = <String>{};

  @override
  void dispose() {
    _titulo.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final r = await ref.read(apiProvider).post('/campanas', {
        'titulo': _titulo.text,
        'mensaje': _mensaje.text,
        'segmento': _segmento,
        'cupon_id': ?_cupon,
      });
      ref.invalidate(campanasProvider);
      if (!mounted) return;
      avisar(context, 'Enviada a ${r['con_app']} con la app.');
      setState(() => _sinApp = _lista(r['sin_app']));
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cupones = _lista(ref.watch(cuponesProvider).value?['cupones']).where((c) => c['vigente'] == true).toList();
    final segmentos = _lista(ref.watch(cuponesProvider).value?['segmentos']);
    final historial = ref.watch(campanasProvider).value;
    final quedan = historial?['quedan_semana'] as int? ?? 2;
    if (_sinApp != null) return _listaWhatsapp(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar una promoción')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _segmento,
            decoration: const InputDecoration(labelText: '¿A quién?'),
            items: [
              for (final s in segmentos)
                DropdownMenuItem(value: s['clave'] as String, child: Text('${s['nombre']} (${s['clientes']})')),
            ],
            onChanged: (v) => setState(() => _segmento = v ?? 'todos'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campana-titulo'),
            controller: _titulo,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Título', hintText: 'Te extrañamos'),
          ),
          TextField(
            key: const Key('campana-mensaje'),
            controller: _mensaje,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              hintText: 'esta semana tienes 20 % en tu limpieza.',
            ),
          ),
          DropdownButtonFormField<int?>(
            initialValue: _cupon,
            decoration: const InputDecoration(labelText: 'Adjuntar cupón'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin cupón')),
              for (final c in cupones)
                DropdownMenuItem(value: c['id'] as int, child: Text('${c['codigo']} · ${c['titulo']}')),
            ],
            onChanged: (v) => setState(() => _cupon = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('campana-enviar'),
            onPressed: _enviando || quedan == 0 ? null : _enviar,
            icon: const Icon(Icons.send_rounded),
            label: Text(quedan == 0 ? 'Ya enviaste 2 esta semana' : 'Enviar'),
          ),
          const SizedBox(height: 6),
          Text(
            'Hasta 2 promociones por semana, para no cansar a tus clientes. Quien la tiene, la recibe en su app; '
            'para el resto te damos los WhatsApp con el mensaje listo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (historial != null && _lista(historial['campanas']).isNotEmpty) ...[
            const TituloGrupo('Enviadas'),
            for (final c in _lista(historial['campanas']))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c['titulo'] as String),
                subtitle: Text('${c['segmento_nombre']} · ${c['destinatarios']} clientes, ${c['con_app']} con la app'),
                trailing: Text(Fechas.diaCorto((c['fecha'] as String).substring(0, 10))),
              ),
          ],
        ],
      ),
    );
  }

  Widget _listaWhatsapp(BuildContext context) {
    final lista = _sinApp!;
    return Scaffold(
      appBar: AppBar(title: const Text('Avisar por WhatsApp')),
      body: lista.isEmpty
          ? const Vacio('¡Listo! Todos la recibieron en su app.', icono: Icons.check_circle_outline_rounded)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${lista.length} no tienen la app. Tócalos uno por uno: el mensaje ya está escrito.'),
                const SizedBox(height: 8),
                for (final p in lista)
                  Card(
                    child: ListTile(
                      leading: Avatar(p['nombre'] as String),
                      title: Text(p['nombre'] as String),
                      subtitle: Text(p['celular'] as String),
                      trailing: _enviados.contains(p['celular'])
                          ? const Icon(Icons.check_rounded, color: Colors.green)
                          : const Icon(Icons.chat_rounded),
                      onTap: () async {
                        await abrirWhatsapp(context, p['whatsapp_url'] as String);
                        setState(() => _enviados.add(p['celular'] as String));
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

/// En la ficha del cliente: su tarjeta, entregar el premio o regalar un sello.
class TarjetaDelCliente extends ConsumerWidget {
  const TarjetaDelCliente({super.key, required this.pacienteId});

  final int pacienteId;

  Future<void> _accion(BuildContext context, WidgetRef ref, String ruta, String hecho) async {
    try {
      await ref.read(apiProvider).post('/pacientes/$pacienteId/$ruta');
      ref.invalidate(tarjetaPacienteProvider(pacienteId));
      if (context.mounted) avisar(context, hecho);
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tarjetaPacienteProvider(pacienteId)).value;
    if (t == null || t['activa'] != true) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    final nivel = t['nivel'] as Json;
    final lista = t['lista'] == true;
    final general = ref.watch(negocioActualProvider).esGeneral;
    return Card(
      key: const Key('tarjeta-del-cliente'),
      color: esquema.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nivel ${nivel['nombre']} · ${t['sellos']}/${t['meta']} sellos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (t['tiene_app'] == true)
                  const Chip(label: Text('Tiene la app'), visualDensity: VisualDensity.compact),
              ],
            ),
            Text(lista ? 'Tarjeta llena: le toca ${t['premio']}.' : 'Premio: ${t['premio']}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (lista)
                  FilledButton.icon(
                    key: const Key('entregar-premio'),
                    onPressed: () async {
                      final ok = await confirmar(
                        context,
                        '¿Entregaste el premio?',
                        '${t['premio']}. La tarjeta empieza de nuevo.',
                        accion: 'Sí, entregado',
                      );
                      if (ok && context.mounted) await _accion(context, ref, 'canjear', 'Premio entregado');
                    },
                    icon: const Icon(Icons.redeem_rounded),
                    label: const Text('Entregar premio'),
                  ),
                if (general)
                  OutlinedButton.icon(
                    onPressed: () => _accion(context, ref, 'regalar-sello', 'Sello regalado'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Regalar un sello'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
