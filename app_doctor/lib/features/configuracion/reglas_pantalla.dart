import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../shared/comunes.dart';

/// Reglas de reserva: con cuánta anticipación reservan los clientes y hasta cuándo pueden cancelar o mover su cita
/// desde la app. Solo la cuenta general las cambia.
class ReglasPantalla extends ConsumerStatefulWidget {
  const ReglasPantalla({super.key});

  @override
  ConsumerState<ReglasPantalla> createState() => _ReglasPantallaState();
}

class _ReglasPantallaState extends ConsumerState<ReglasPantalla> {
  Map<String, dynamic>? _datos;
  Object? _error;
  bool _guardando = false;

  static const _anticipacion = {0: 'Sin mínimo', 1: '1 hora', 2: '2 horas', 4: '4 horas', 24: '1 día'};
  static const _plazo = {0: 'Hasta la hora', 2: '2 h antes', 4: '4 h antes', 12: '12 h antes', 24: '1 día antes'};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final datos = await ref.read(apiProvider).get('/reglas');
      if (mounted) setState(() => _datos = datos);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _guardar(String campo, int valor) async {
    setState(() => _guardando = true);
    try {
      final datos = await ref.read(apiProvider).put('/reglas', {campo: valor});
      if (mounted) setState(() => _datos = datos);
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _grupo(String titulo, String explicacion, String campo, Map<int, String> opciones) {
    final datos = _datos!;
    final puede = datos['puede_cambiar'] == true && !_guardando;
    final actual = datos[campo] as int?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(explicacion, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in {
                  ...opciones,
                  if (actual != null && !opciones.containsKey(actual)) actual: '$actual h',
                }.entries)
                  ChoiceChip(
                    key: Key('$campo-${e.key}'),
                    label: Text(e.value),
                    selected: actual == e.key,
                    onSelected: puede ? (_) => _guardar(campo, e.key) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    return Scaffold(
      appBar: AppBar(title: const Text('Reglas de reserva')),
      body: datos == null
          ? (_error != null ? ErrorConReintento(error: _error!, alReintentar: _cargar) : const Cargando())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _grupo(
                  'Anticipación mínima',
                  'Cuánto antes deben reservar los clientes en la web y en la app. Con «2 horas» y cierre a las 6 p. m., '
                      'desde las 4 p. m. ya no se puede reservar para ese día. Tú siempre puedes agendar a cualquier hora.',
                  'anticipacion_min_horas',
                  _anticipacion,
                ),
                const SizedBox(height: 8),
                _grupo(
                  'Cancelar o mover desde la app',
                  'Hasta cuándo el cliente puede cancelar o mover su cita por su cuenta. Después, te escribe por '
                      'WhatsApp. Si la mueve, la nueva hora te llega como «por confirmar».',
                  'limite_cancelacion_horas',
                  _plazo,
                ),
                if (datos['puede_cambiar'] != true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Solo la cuenta general del negocio cambia estas reglas.'),
                  ),
              ],
            ),
    );
  }
}
