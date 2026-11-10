import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/tema.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';
import '../citas/acciones_cita.dart';
import 'hoy_pantalla.dart' show FiltroProfesional;

final semanaProvider = FutureProvider.autoDispose.family<List<DiaSemana>, String>((ref, desde) async {
  final extra = ref.watch(parametroProfesionalProvider);
  final datos = await ref.read(apiProvider).get('/agenda/semana', params: {'desde': desde, ...extra});
  return (datos['dias'] as List).map((d) => DiaSemana.fromJson(d as Map<String, dynamic>)).toList();
});

final mesProvider = FutureProvider.autoDispose.family<List<DiaMes>, (int, int)>((ref, mes) async {
  final extra = ref.watch(parametroProfesionalProvider);
  final datos = await ref.read(apiProvider).get('/agenda/mes', params: {'anio': mes.$1, 'mes': mes.$2, ...extra});
  return (datos['dias'] as List).map((d) => DiaMes.fromJson(d as Map<String, dynamic>)).toList();
});

enum Vista { semana, mes }

class SemanaPantalla extends ConsumerStatefulWidget {
  const SemanaPantalla({super.key});

  @override
  ConsumerState<SemanaPantalla> createState() => _SemanaPantallaState();
}

class _SemanaPantallaState extends ConsumerState<SemanaPantalla> {
  late DateTime _desde = DateTime(Fechas.ahora().year, Fechas.ahora().month, Fechas.ahora().day);
  late DateTime _mes = DateTime(_desde.year, _desde.month);
  Vista _vista = Vista.semana;

  void _mover(int paso) => setState(() {
    if (_vista == Vista.semana) {
      _desde = _desde.add(Duration(days: 7 * paso));
    } else {
      _mes = DateTime(_mes.year, _mes.month + paso);
    }
  });

  /// Tocar un día del mes abre la semana que empieza ese día.
  void _abrirDia(DateTime dia) => setState(() {
    _desde = dia;
    _vista = Vista.semana;
  });

  @override
  Widget build(BuildContext context) {
    final esSemana = _vista == Vista.semana;
    return Scaffold(
      appBar: AppBar(
        title: Text(esSemana ? 'Semana' : _tituloMes(_mes)),
        actions: [
          const FiltroProfesional(),
          IconButton(
            tooltip: esSemana ? 'Semana anterior' : 'Mes anterior',
            onPressed: () => _mover(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: esSemana ? 'Semana siguiente' : 'Mes siguiente',
            onPressed: () => _mover(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<Vista>(
              segments: const [
                ButtonSegment(value: Vista.semana, label: Text('Semana'), icon: Icon(Icons.view_week_outlined)),
                ButtonSegment(value: Vista.mes, label: Text('Mes'), icon: Icon(Icons.calendar_month_outlined)),
              ],
              selected: {_vista},
              onSelectionChanged: (v) => setState(() => _vista = v.first),
            ),
          ),
        ),
      ),
      body: esSemana ? _semana() : _Mes(mes: _mes, alElegir: _abrirDia),
    );
  }

  String _tituloMes(DateTime mes) {
    final texto = DateFormat('MMMM yyyy', 'es').format(mes);
    return texto[0].toUpperCase() + texto.substring(1);
  }

  Widget _semana() {
    final clave = Fechas.fechaApi(_desde);
    final semana = ref.watch(semanaProvider(clave));
    return semana.when(
      loading: () => const Cargando(),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(semanaProvider(clave))),
      data: (dias) => RefreshIndicator(
        onRefresh: () => ref.refresh(semanaProvider(clave).future),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dias.length,
          itemBuilder: (_, i) => _Dia(dia: dias[i], alCambiar: () => ref.invalidate(semanaProvider(clave))),
        ),
      ),
    );
  }
}

/// Cuadrícula del mes: cuántas citas tiene cada día, las por confirmar y los días bloqueados.
class _Mes extends ConsumerWidget {
  const _Mes({required this.mes, required this.alElegir});

  final DateTime mes;
  final void Function(DateTime) alElegir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = (mes.year, mes.month);
    final datos = ref.watch(mesProvider(clave));
    return datos.when(
      loading: () => const Cargando(),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(mesProvider(clave))),
      data: (dias) {
        final hoy = Fechas.fechaApi(Fechas.ahora());
        final vacios = DateTime.parse(dias.first.fecha).weekday - 1; // la semana empieza en lunes
        return RefreshIndicator(
          onRefresh: () => ref.refresh(mesProvider(clave).future),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                    Expanded(
                      child: Center(
                        child: Text(d, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.8,
                children: [
                  for (var i = 0; i < vacios; i++) const SizedBox.shrink(),
                  for (final d in dias)
                    _CeldaDia(dia: d, esHoy: d.fecha == hoy, alTocar: () => alElegir(DateTime.parse(d.fecha))),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'El número es la cantidad de citas. Naranja: hay reservas por confirmar. Gris: día bloqueado.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CeldaDia extends StatelessWidget {
  const _CeldaDia({required this.dia, required this.esHoy, required this.alTocar});

  final DiaMes dia;
  final bool esHoy;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = dia.bloqueo
        ? esquema.surfaceContainerHighest
        : dia.porConfirmar > 0
        ? const Color(0xFFFFE8CC)
        : dia.citas > 0
        ? esquema.primaryContainer
        : null;
    return Material(
      color: fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: esHoy ? BorderSide(color: esquema.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: alTocar,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${DateTime.parse(dia.fecha).day}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (dia.citas > 0)
              Text('${dia.citas}', key: Key('citas-${dia.fecha}'), style: Theme.of(context).textTheme.bodySmall),
            if (dia.bloqueo && dia.citas == 0) const Icon(Icons.block, size: 14),
          ],
        ),
      ),
    );
  }
}

class _Dia extends ConsumerWidget {
  const _Dia({required this.dia, required this.alCambiar});

  final DiaSemana dia;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titulo = Fechas.diaLargo(dia.fecha);
    final negocio = ref.watch(negocioActualProvider);
    final verQuien = negocio.porProfesional && negocio.esGeneral;
    final conCitas = dia.turnos.where((t) => t.citas > 0).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo[0].toUpperCase() + titulo.substring(1),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          // «Mañana 2 · Tarde 1 (1 por confirmar)»: cuánto trae cada turno, sin abrir el día.
          if (dia.turnos.length > 1 && conCitas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  for (final t in conCitas)
                    '${t.nombre} ${t.citas}${t.porConfirmar > 0 ? ' (${t.porConfirmar} por confirmar)' : ''}',
                ].join(' · '),
                key: Key('turnos-${dia.fecha}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 6),
          if (dia.citas.isEmpty && dia.bloqueos.isEmpty)
            Text('Sin citas', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          for (final b in dia.bloqueos)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block),
              title: Text(b.motivo.isEmpty ? 'Bloqueado' : b.motivo),
              subtitle: Text('${Fechas.diaHora(b.inicio)} a ${Fechas.diaHora(b.fin)}'),
            ),
          for (final c in dia.citas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Avatar(c.paciente.nombre, radio: 20),
                  title: Text(c.paciente.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      Fechas.hora(c.inicio),
                      c.tratamiento.nombre,
                      if (verQuien && c.profesional != null) 'con ${c.profesional!.nombre}',
                      c.estadoTexto,
                    ].join(' · '),
                  ),
                  trailing: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: ColoresEstado.de(c.estado, Theme.of(context).colorScheme),
                      shape: BoxShape.circle,
                    ),
                  ),
                  onTap: () => mostrarAccionesCita(context, ref, c, alCambiar: alCambiar),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
