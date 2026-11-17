import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';

/// [profesionalId] null: cualquiera que haga el servicio (o la agenda propia, si la cuenta es de un profesional).
typedef ConsultaLibres = ({int tratamientoId, int? excluirCita, int? profesionalId});

final horasLibresProvider = FutureProvider.autoDispose.family<List<DiaLibre>, ConsultaLibres>((ref, c) async {
  final datos = await ref
      .read(apiProvider)
      .get(
        '/citas/disponibilidad',
        params: {
          'tratamiento_id': c.tratamientoId,
          'dias': 30,
          'excluir_cita': ?c.excluirCita,
          'profesional': ?c.profesionalId,
        },
      );
  return (datos['dias'] as List).map((d) => DiaLibre.fromJson(d as Map<String, dynamic>)).toList();
});

/// Solo ofrece horas libres, calculadas por el mismo motor que la reserva web (RF-23).
class SelectorHora extends ConsumerStatefulWidget {
  const SelectorHora({super.key, this.consulta, this.fuente, required this.alElegir, this.fechaPreferida})
    : assert(consulta != null || fuente != null);

  /// Día que la persona ya eligió en el calendario (YYYY-MM-DD): se abre en ese día si tiene horas libres.
  final String? fechaPreferida;

  final ConsultaLibres? consulta;

  /// Otra fuente de horas libres (la app del cliente consulta su propia API).
  final AutoDisposeFutureProvider<List<DiaLibre>>? fuente;
  final ValueChanged<String> alElegir;

  @override
  ConsumerState<SelectorHora> createState() => _SelectorHoraState();
}

class _SelectorHoraState extends ConsumerState<SelectorHora> {
  int _dia = 0;
  bool _preferidaAplicada = false;
  bool _sinHorasEseDia = false;

  @override
  Widget build(BuildContext context) {
    final fuente = widget.fuente ?? horasLibresProvider(widget.consulta!);
    final libres = ref.watch(fuente);
    return libres.when(
      loading: () => const Cargando(),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(fuente)),
      data: (dias) {
        if (dias.isEmpty) return const Vacio('No hay horas libres en los próximos 30 días.');
        if (!_preferidaAplicada && widget.fechaPreferida != null) {
          _preferidaAplicada = true;
          final i = dias.indexWhere((d) => d.fecha == widget.fechaPreferida);
          if (i >= 0) {
            _dia = i;
          } else {
            _sinHorasEseDia = true;
          }
        }
        final dia = dias[_dia.clamp(0, dias.length - 1)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sinHorasEseDia)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Ese día ya no tiene horas libres; te mostramos el más cercano.',
                  key: const Key('sin-horas-ese-dia'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: dias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(Fechas.diaCorto(dias[i].fecha)),
                  selected: i == _dia,
                  onSelected: (_) => setState(() {
                    _dia = i;
                    _sinHorasEseDia = false;
                  }),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100,
                  mainAxisExtent: 52,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: dia.horas.length,
                itemBuilder: (_, i) => OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => widget.alElegir(dia.horas[i]),
                  child: Text(Fechas.hora(dia.horas[i])),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
