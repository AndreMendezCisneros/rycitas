import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/fechas.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import 'datos_cliente.dart';
import 'widgets_cliente.dart';

/// Hoja flotante con los lugares donde se puede reservar: primero los suyos, luego «Descubre» (filtrable por rubro).
/// La abren Rubí y el calendario de «Mis citas» (con [dia], que pasa a la reserva como día preferido).
Future<void> mostrarLugaresParaReservar(BuildContext context, {DateTime? dia, Widget? encabezado}) =>
    mostrarHojaVidrio<void>(
      context,
      altoCompleto: true,
      builder: (_) => _Lugares(dia: dia, encabezado: encabezado),
    );

class _Lugares extends ConsumerStatefulWidget {
  const _Lugares({this.dia, this.encabezado});

  final DateTime? dia;
  final Widget? encabezado;

  @override
  ConsumerState<_Lugares> createState() => _LugaresState();
}

class _LugaresState extends ConsumerState<_Lugares> {
  String _rubro = '';

  void _reservar(Json negocio) {
    Navigator.pop(context);
    final fecha = widget.dia == null ? '' : '?fecha=${Fechas.fechaApi(widget.dia!)}';
    context.push('/cliente/negocio/${negocio['slug']}$fecha');
  }

  @override
  Widget build(BuildContext context) {
    final mios = ref.watch(misNegociosProvider);
    final descubre = ref.watch(busquedaProvider((q: '', rubro: _rubro)));
    final textos = Theme.of(context).textTheme;
    final misSlugs = {for (final n in lista(mios.value?['negocios'])) n['slug']};
    final otros = lista(descubre.value?['negocios']).where((n) => !misSlugs.contains(n['slug'])).toList();
    final rubros = lista(descubre.value?['rubros']);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ?widget.encabezado,
        if (widget.dia != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Para el ${Fechas.diaLargo(Fechas.fechaApi(widget.dia!))}',
              style: textos.bodyMedium?.copyWith(color: Paleta.textoSuave),
            ),
          ),
        if (lista(mios.value?['negocios']).isNotEmpty) ...[
          Text('Tus lugares', style: textos.titleMedium),
          const SizedBox(height: 8),
          for (final n in lista(mios.value?['negocios'])) _FilaLugar(negocio: n, alReservar: () => _reservar(n)),
          const SizedBox(height: 16),
        ],
        Text('Descubre', style: textos.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: const Text('Todos'), selected: _rubro.isEmpty, onSelected: (_) => setState(() => _rubro = '')),
              ),
              for (final r in rubros)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r['nombre'] as String),
                    selected: _rubro == r['clave'],
                    onSelected: (_) => setState(() => _rubro = r['clave'] as String),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (descubre.isLoading) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        for (final n in otros) _FilaLugar(negocio: n, alReservar: () => _reservar(n)),
        if (!descubre.isLoading && otros.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No hay más lugares por ahora.', style: TextStyle(color: Paleta.textoSuave)),
          ),
      ],
    );
  }
}

class _FilaLugar extends StatelessWidget {
  const _FilaLugar({required this.negocio, required this.alReservar});

  final Json negocio;
  final VoidCallback alReservar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        FotoNegocio(negocio: negocio, lado: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(negocio['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                negocio['rubro_nombre'] as String? ?? '',
                style: const TextStyle(color: Paleta.textoSuave, fontSize: 12.5),
              ),
            ],
          ),
        ),
        FilledButton.tonal(
          key: Key('reservar-en-${negocio['slug']}'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: Paleta.rosa,
            foregroundColor: Paleta.frambuesa,
          ),
          onPressed: negocio['acepta_reservas'] == false ? null : alReservar,
          child: const Text('Reservar'),
        ),
      ],
    ),
  );
}
