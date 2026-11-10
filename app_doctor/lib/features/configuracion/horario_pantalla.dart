import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';

/// Horario semanal con uno o varios tramos por día (RF-25). Se guarda todo junto.
class HorarioPantalla extends ConsumerStatefulWidget {
  const HorarioPantalla({super.key});

  @override
  ConsumerState<HorarioPantalla> createState() => _HorarioPantallaState();
}

class _HorarioPantallaState extends ConsumerState<HorarioPantalla> {
  List<Tramo>? _tramos;
  Object? _error;
  bool _guardando = false;
  bool _cambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final datos = await ref.read(apiProvider).get('/horario');
      if (mounted) {
        setState(
          () => _tramos = (datos['tramos'] as List).map((t) => Tramo.fromJson(t as Map<String, dynamic>)).toList(),
        );
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<TimeOfDay?> _elegirHora(String titulo, TimeOfDay inicial) {
    return showTimePicker(
      context: context,
      initialTime: inicial,
      helpText: titulo,
      builder: (context, hijo) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: hijo!),
    );
  }

  Future<void> _agregar(int dia) async {
    final inicio = await _elegirHora('Abre a las', const TimeOfDay(hour: 9, minute: 0));
    if (inicio == null) return;
    final fin = await _elegirHora('Cierra a las', const TimeOfDay(hour: 13, minute: 0));
    if (fin == null || !mounted) return;
    if (inicio.hour * 60 + inicio.minute >= fin.hour * 60 + fin.minute) {
      avisar(context, 'La hora de cierre debe ser después de la de apertura.');
      return;
    }
    setState(() {
      _tramos!.add(Tramo(diaSemana: dia, horaInicio: Fechas.horaDe(inicio), horaFin: Fechas.horaDe(fin)));
      _cambios = true;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await ref.read(apiProvider).put('/horario', {
        'tramos': [
          for (final t in _tramos!) {'dia_semana': t.diaSemana, 'hora_inicio': t.horaInicio, 'hora_fin': t.horaFin},
        ],
      });
      if (mounted) {
        setState(() => _cambios = false);
        avisar(context, 'Horario guardado. Ya se refleja en tu sitio.');
      }
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tramos = _tramos;
    return Scaffold(
      appBar: AppBar(title: const Text('Horario de atención')),
      bottomNavigationBar: tramos == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _cambios && !_guardando ? _guardar : null,
                  child: Text(_guardando ? 'Guardando…' : 'Guardar horario'),
                ),
              ),
            ),
      body: _error != null
          ? ErrorConReintento(error: _error!, alReintentar: _cargar)
          : tramos == null
          ? const Cargando()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 7,
              itemBuilder: (_, dia) {
                final delDia = tramos.where((t) => t.diaSemana == dia).toList()
                  ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(Fechas.dias[dia], style: Theme.of(context).textTheme.titleMedium)),
                              TextButton.icon(
                                onPressed: () => _agregar(dia),
                                icon: const Icon(Icons.add),
                                label: const Text('Tramo'),
                              ),
                            ],
                          ),
                          if (delDia.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text('Cerrado', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ),
                          for (final t in delDia)
                            Row(
                              children: [
                                Expanded(child: Text('${t.horaInicio} a ${t.horaFin}')),
                                IconButton(
                                  tooltip: 'Quitar tramo',
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    tramos.remove(t);
                                    _cambios = true;
                                  }),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
