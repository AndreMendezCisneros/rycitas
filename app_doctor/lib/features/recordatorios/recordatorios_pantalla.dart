import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';

typedef Recordatorios = ({String fecha, List<Cita> citas});

/// Por defecto, las citas de mañana.
final recordatoriosProvider = FutureProvider.autoDispose.family<Recordatorios, String?>((ref, fecha) async {
  final datos = await ref
      .read(apiProvider)
      .get('/citas/recordatorios', params: fecha == null ? null : {'fecha': fecha});
  return (
    fecha: datos['fecha'] as String,
    citas: (datos['citas'] as List).map((c) => Cita.fromJson(c as Map<String, dynamic>)).toList(),
  );
});

/// El doctor recuerda cada cita desde su propio WhatsApp con un toque y marca quién confirmó (sin costo).
class RecordatoriosPantalla extends ConsumerStatefulWidget {
  const RecordatoriosPantalla({super.key});

  @override
  ConsumerState<RecordatoriosPantalla> createState() => _RecordatoriosPantallaState();
}

class _RecordatoriosPantallaState extends ConsumerState<RecordatoriosPantalla> {
  String? _fecha;

  void _recargar() => ref.invalidate(recordatoriosProvider(_fecha));

  void _moverDia(String actual, int dias) {
    final nueva = DateTime.parse(actual).add(Duration(days: dias));
    setState(() => _fecha = Fechas.fechaApi(nueva));
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(recordatoriosProvider(_fecha));
    final fecha = datos.value?.fecha;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          if (fecha != null) ...[
            IconButton(
              tooltip: 'Día anterior',
              onPressed: () => _moverDia(fecha, -1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Día siguiente',
              onPressed: () => _moverDia(fecha, 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ],
      ),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: _recargar),
        data: (r) {
          final enviados = r.citas.where((c) => c.recordatorioEnviadoEn != null).length;
          final titulo = Fechas.diaLargo(r.fecha);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(recordatoriosProvider(_fecha).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(titulo[0].toUpperCase() + titulo.substring(1), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  r.citas.isEmpty
                      ? 'No hay citas confirmadas este día.'
                      : '$enviados de ${r.citas.length} recordatorios enviados. Toca «Enviar» y luego Enviar en WhatsApp.',
                ),
                const SizedBox(height: 12),
                for (final c in r.citas) _FilaRecordatorio(cita: c, alCambiar: _recargar),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilaRecordatorio extends ConsumerWidget {
  const _FilaRecordatorio({required this.cita, required this.alCambiar});

  final Cita cita;
  final VoidCallback alCambiar;

  Future<void> _enviar(BuildContext context, WidgetRef ref) async {
    final url = cita.whatsappUrl;
    if (url == null) return;
    await abrirWhatsapp(context, url);
    try {
      await ref.read(apiProvider).post('/citas/${cita.id}/recordado');
      alCambiar();
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  Future<void> _asistencia(BuildContext context, WidgetRef ref, bool? confirmada) async {
    try {
      await ref.read(apiProvider).post('/citas/${cita.id}/asistencia', {'confirmada': confirmada});
      alCambiar();
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enviado = cita.recordatorioEnviadoEn != null;
    final asistencia = cita.asistenciaConfirmada;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(Fechas.hora(cita.inicio), style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cita.paciente.nombre, style: Theme.of(context).textTheme.titleMedium),
                      Text(cita.tratamiento.nombre),
                    ],
                  ),
                ),
                if (asistencia == true) const Chip(label: Text('Confirmó')),
                if (asistencia == false) const Chip(label: Text('No vendrá')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: enviado
                      ? OutlinedButton.icon(
                          onPressed: () => _enviar(context, ref),
                          icon: const Icon(Icons.check),
                          label: const Text('Enviado'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _enviar(context, ref),
                          icon: const Icon(Icons.chat),
                          label: const Text('Enviar'),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _asistencia(context, ref, asistencia == true ? null : true),
                    child: Text(asistencia == true ? 'Desmarcar' : 'Confirmó'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
