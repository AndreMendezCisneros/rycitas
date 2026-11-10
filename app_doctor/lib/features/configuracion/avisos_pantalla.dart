import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../shared/comunes.dart';

/// Qué notificaciones recibe esta cuenta en este teléfono, y (solo la cuenta general) cuánto antes de cada cita
/// se avisa al profesional que la atiende.
class AvisosPantalla extends ConsumerStatefulWidget {
  const AvisosPantalla({super.key});

  @override
  ConsumerState<AvisosPantalla> createState() => _AvisosPantallaState();
}

class _AvisosPantallaState extends ConsumerState<AvisosPantalla> {
  Map<String, dynamic>? _datos;
  Object? _error;
  bool _guardando = false;

  static const _minutos = {0: 'No avisar', 10: '10 min antes', 15: '15 min antes', 30: '30 min antes', 60: '1 hora antes'};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final datos = await ref.read(apiProvider).get('/avisos');
      if (mounted) setState(() => _datos = datos);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<Map<String, dynamic>> get _tipos => [for (final t in _datos!['tipos'] as List) (t as Map).cast<String, dynamic>()];

  Future<void> _guardar({String? tipo, bool? activo, int? minutos}) async {
    final apagados = [
      for (final t in _tipos)
        if (t['tipo'] == tipo ? activo == false : t['activo'] != true) t['tipo'] as String,
    ];
    setState(() => _guardando = true);
    try {
      final datos = await ref.read(apiProvider).put('/avisos', {
        'apagados': apagados,
        'recordar_cita_min': ?minutos,
      });
      if (mounted) setState(() => _datos = datos);
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: datos == null
          ? (_error != null ? ErrorConReintento(error: _error!, alReintentar: _cargar) : const Cargando())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Llegan a este teléfono aunque la app esté cerrada. Lo que apagues aquí solo cambia para tu cuenta.',
                  style: textos.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final t in _tipos)
                        SwitchListTile(
                          key: Key('aviso-${t['tipo']}'),
                          title: Text(t['nombre'] as String),
                          subtitle: t['tipo'] == 'cita_proxima'
                              ? Text(_minutos[datos['recordar_cita_min']] ?? '')
                              : null,
                          value: t['activo'] == true,
                          onChanged: _guardando ? null : (v) => _guardar(tipo: t['tipo'] as String, activo: v),
                        ),
                    ],
                  ),
                ),
                if (datos['puede_cambiar_minutos'] == true) ...[
                  const TituloGrupo('Antes de cada cita'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A quien atiende la cita le llega «En 30 min: Rosa Paz». Vale para todo el negocio.',
                            style: textos.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final e in _minutos.entries)
                                ChoiceChip(
                                  key: Key('minutos-${e.key}'),
                                  label: Text(e.value),
                                  selected: datos['recordar_cita_min'] == e.key,
                                  onSelected: _guardando ? null : (_) => _guardar(minutos: e.key),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
