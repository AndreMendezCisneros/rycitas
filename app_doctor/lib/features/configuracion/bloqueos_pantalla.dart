import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/negocio.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';

final bloqueosProvider = FutureProvider.autoDispose<List<Bloqueo>>((ref) async {
  final datos = await ref.read(apiProvider).get('/bloqueos');
  return (datos['bloqueos'] as List).map((b) => Bloqueo.fromJson(b as Map<String, dynamic>)).toList();
});

class BloqueosPantalla extends ConsumerWidget {
  const BloqueosPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloqueos = ref.watch(bloqueosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _NuevoBloqueo()));
          ref.invalidate(bloqueosProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo bloqueo'),
      ),
      body: bloqueos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(bloqueosProvider)),
        data: (lista) => lista.isEmpty
            ? const Vacio('No tienes bloqueos.')
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final b in lista)
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(b.motivo.isEmpty ? 'Bloqueado' : b.motivo),
                      subtitle: Text('${Fechas.diaHora(b.inicio)} a ${Fechas.diaHora(b.fin)}'),
                      trailing: IconButton(
                        tooltip: 'Quitar bloqueo',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await ref.read(apiProvider).delete('/bloqueos/${b.id}');
                            ref.invalidate(bloqueosProvider);
                          } on ApiError catch (e) {
                            if (context.mounted) avisar(context, e.mensaje);
                          }
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NuevoBloqueo extends ConsumerStatefulWidget {
  const _NuevoBloqueo();

  @override
  ConsumerState<_NuevoBloqueo> createState() => _NuevoBloqueoState();
}

class _NuevoBloqueoState extends ConsumerState<_NuevoBloqueo> {
  final _motivo = TextEditingController();
  bool _diaCompleto = true;
  bool _enviando = false;
  late DateTime _desde;
  late DateTime _hasta;
  TimeOfDay _horaDesde = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaHasta = const TimeOfDay(hour: 13, minute: 0);

  @override
  void initState() {
    super.initState();
    final hoy = Fechas.ahora();
    _desde = DateTime(hoy.year, hoy.month, hoy.day);
    _hasta = _desde;
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  (String, String) get _rango {
    if (_diaCompleto) {
      return (
        Fechas.instanteApi(_desde, const TimeOfDay(hour: 0, minute: 0)),
        Fechas.instanteApi(_hasta.add(const Duration(days: 1)), const TimeOfDay(hour: 0, minute: 0)),
      );
    }
    return (Fechas.instanteApi(_desde, _horaDesde), Fechas.instanteApi(_desde, _horaHasta));
  }

  Future<DateTime?> _elegirFecha(DateTime inicial) {
    final hoy = Fechas.ahora();
    return showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 2),
    );
  }

  /// Si el bloqueo afecta citas, las muestra antes de confirmar (RF-26).
  Future<void> _guardar() async {
    final (inicio, fin) = _rango;
    if (DateTime.parse(inicio).compareTo(DateTime.parse(fin)) >= 0) {
      avisar(context, 'El bloqueo debe terminar después de empezar.');
      return;
    }
    setState(() => _enviando = true);
    final api = ref.read(apiProvider);
    try {
      final impacto = await api.get('/bloqueos/impacto', params: {'inicio': inicio, 'fin': fin});
      final afectadas = (impacto['citas'] as List).map((c) => Cita.fromJson(c as Map<String, dynamic>)).toList();
      if (afectadas.isNotEmpty && mounted) {
        final seguir = await confirmar(
          context,
          afectadas.length == 1 ? 'Hay 1 cita en ese horario' : 'Hay ${afectadas.length} citas en ese horario',
          '${afectadas.map((c) => '• ${Fechas.diaHora(c.inicio)}: ${c.paciente.nombre}').join('\n')}\n\n'
          'Las citas no se cancelan solas: muévelas o cancélalas desde la agenda para avisar a cada ${vocDe(context).cliente}.',
          accion: 'Bloquear igual',
        );
        if (!seguir) return;
      }
      await api.post('/bloqueos', {'inicio': inicio, 'fin': fin, 'motivo': _motivo.text.trim()});
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String fecha(DateTime d) => Fechas.diaLargo(Fechas.fechaApi(d));
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo bloqueo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Días completos'),
            value: _diaCompleto,
            onChanged: (v) => setState(() => _diaCompleto = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_diaCompleto ? 'Desde' : 'Día'),
            subtitle: Text(fecha(_desde)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await _elegirFecha(_desde);
              if (d != null) {
                setState(() {
                  _desde = d;
                  if (_hasta.isBefore(d)) _hasta = d;
                });
              }
            },
          ),
          if (_diaCompleto)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hasta'),
              subtitle: Text(fecha(_hasta)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await _elegirFecha(_hasta);
                if (d != null && !d.isBefore(_desde)) setState(() => _hasta = d);
              },
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('De'),
              subtitle: Text(Fechas.horaDe(_horaDesde)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final h = await showTimePicker(context: context, initialTime: _horaDesde);
                if (h != null) setState(() => _horaDesde = h);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('A'),
              subtitle: Text(Fechas.horaDe(_horaHasta)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final h = await showTimePicker(context: context, initialTime: _horaHasta);
                if (h != null) setState(() => _horaHasta = h);
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _enviando ? null : _guardar, child: Text(_enviando ? 'Guardando…' : 'Crear bloqueo')),
        ],
      ),
    );
  }
}
