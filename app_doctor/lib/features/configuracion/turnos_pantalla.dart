import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../agenda/agenda_controlador.dart';

/// En cuántos turnos se divide la agenda del día (mañana, tarde, noche) y a qué hora termina cada uno.
/// Solo la cuenta general la cambia; vale para todo el negocio.
class TurnosPantalla extends ConsumerStatefulWidget {
  const TurnosPantalla({super.key});

  static const maximo = 3;

  @override
  ConsumerState<TurnosPantalla> createState() => _TurnosPantallaState();
}

class _Fila {
  _Fila(String nombre, this.hasta) : nombre = TextEditingController(text: nombre);

  final TextEditingController nombre;
  TimeOfDay? hasta; // null: el último, hasta el fin del día
}

class _TurnosPantallaState extends ConsumerState<TurnosPantalla> {
  late final List<_Fila> _filas;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final turnos = ref.read(negocioActualProvider).turnos;
    _filas = [
      for (var i = 0; i < turnos.length; i++)
        _Fila(turnos[i].nombre, i == turnos.length - 1 ? null : Fechas.timeOfDay(turnos[i].hasta)),
    ];
  }

  @override
  void dispose() {
    for (final f in _filas) {
      f.nombre.dispose();
    }
    super.dispose();
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _elegirHora(_Fila fila) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: fila.hasta ?? const TimeOfDay(hour: 13, minute: 0),
      helpText: 'Termina a las',
      builder: (context, hijo) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: hijo!),
    );
    if (elegida != null) setState(() => fila.hasta = elegida);
  }

  void _agregar() {
    setState(() {
      // El que era último pasa a tener hora de fin; el nuevo llega al final del día.
      final ultimo = _filas.last;
      ultimo.hasta ??= _filas.length == 1 ? const TimeOfDay(hour: 13, minute: 0) : const TimeOfDay(hour: 18, minute: 0);
      _filas.add(_Fila(_filas.length == 1 ? 'Tarde' : 'Noche', null));
    });
  }

  void _quitar(int i) {
    setState(() {
      _filas.removeAt(i).nombre.dispose();
      _filas.last.hasta = null;
    });
  }

  String? _validar() {
    var anterior = 0;
    for (var i = 0; i < _filas.length; i++) {
      final f = _filas[i];
      if (f.nombre.text.trim().isEmpty) return 'Cada turno necesita un nombre.';
      if (i == _filas.length - 1) break;
      final fin = _min(f.hasta!);
      if (fin <= anterior) return 'Cada turno debe terminar después del anterior.';
      anterior = fin;
    }
    return null;
  }

  Future<void> _guardar() async {
    final error = _validar();
    if (error != null) return setState(() => _error = error);
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).put('/turnos', {
        'turnos': [
          for (final f in _filas)
            {'nombre': f.nombre.text.trim(), 'hasta': f.hasta == null ? '24:00' : Fechas.horaDe(f.hasta!)},
        ],
      });
      ref.invalidate(negocioProvider);
      await ref.read(agendaProvider.notifier).refrescar();
      if (mounted) {
        avisar(context, 'Turnos guardados.');
        Navigator.of(context).pop();
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Turnos de la agenda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'La agenda de «Hoy» se divide en estos turnos. Cada uno muestra arriba las reservas que faltan confirmar.',
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _filas.length; i++)
            Card(
              key: Key('turno-fila-$i'),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filas[i].nombre,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 20,
                        decoration: InputDecoration(labelText: 'Turno ${i + 1}', counterText: ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (i < _filas.length - 1)
                      OutlinedButton(
                        key: Key('turno-hasta-$i'),
                        onPressed: () => _elegirHora(_filas[i]),
                        child: Text('hasta ${Fechas.horaDe(_filas[i].hasta!)}'),
                      )
                    else
                      Text('hasta el cierre', style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
                    if (_filas.length > 1)
                      IconButton(
                        tooltip: 'Quitar turno',
                        onPressed: () => _quitar(i),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                  ],
                ),
              ),
            ),
          if (_filas.length < TurnosPantalla.maximo)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('agregar-turno'),
                onPressed: _agregar,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar turno'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: esquema.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _guardando ? null : _guardar, child: Text(_guardando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}
