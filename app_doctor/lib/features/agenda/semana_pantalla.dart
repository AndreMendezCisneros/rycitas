import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/tema.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/diseno/calendario.dart';
import '../../shared/diseno/movimiento.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import '../../shared/modelos.dart';
import '../citas/reserva_rapida.dart';
import '../citas/acciones_cita.dart';
import 'hoy_pantalla.dart' show FiltroProfesional;
import '../../shared/diseno/tonos.dart';

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

/// «Calendario» del negocio: el mes con la ocupación de cada día. Tocar un día abre una hoja flotante con sus citas;
/// debajo, la semana desde el día elegido.
class SemanaPantalla extends ConsumerStatefulWidget {
  const SemanaPantalla({super.key});

  @override
  ConsumerState<SemanaPantalla> createState() => _SemanaPantallaState();
}

class _SemanaPantallaState extends ConsumerState<SemanaPantalla> {
  late DateTime _elegido = DateTime(Fechas.ahora().year, Fechas.ahora().month, Fechas.ahora().day);
  late DateTime _mes = DateTime(_elegido.year, _elegido.month);

  void _tocarDia(DateTime dia) {
    setState(() => _elegido = dia);
    mostrarHojaDia(context, dia);
  }

  @override
  Widget build(BuildContext context) {
    final clave = (_mes.year, _mes.month);
    final mes = ref.watch(mesProvider(clave));
    final marcas = {
      for (final d in mes.value ?? const <DiaMes>[])
        d.fecha: MarcaDia(
          citas: d.citas,
          porConfirmar: d.porConfirmar,
          bloqueo: d.bloqueo,
          colores: List.filled(d.citas.clamp(0, 3), context.tonos.acento),
        ),
    };
    final desde = Fechas.fechaApi(_elegido);
    final semana = ref.watch(semanaProvider(desde));
    return Scaffold(
      body: FondoManchas(
        intensidad: 0.6,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(mesProvider(clave));
              final _ = await ref.refresh(semanaProvider(desde).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Calendario', style: Theme.of(context).textTheme.headlineMedium)),
                    const FiltroProfesional(),
                  ],
                ),
                const SizedBox(height: 12),
                Vidrio(
                  radio: 28,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: mes.hasError
                      ? ErrorConReintento(error: mes.error!, alReintentar: () => ref.invalidate(mesProvider(clave)))
                      : CalendarioMes(
                          mes: _mes,
                          hoy: Fechas.ahora(),
                          seleccionado: _elegido,
                          marcas: marcas,
                          cargando: mes.isLoading,
                          alCambiarMes: (paso) => setState(() => _mes = DateTime(_mes.year, _mes.month + paso)),
                          alTocarDia: _tocarDia,
                        ),
                ),
                const SizedBox(height: 12),
                LeyendaCalendario(
                  items: [
                    (context.tonos.acento, 'Citas'),
                    (Paleta.ambar, 'Por confirmar'),
                    (Paleta.gris, 'Bloqueado (tachado)'),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Desde el día elegido', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ...semana.when(
                  loading: () => [const Padding(padding: EdgeInsets.all(24), child: Cargando())],
                  error: (e, _) => [
                    ErrorConReintento(error: e, alReintentar: () => ref.invalidate(semanaProvider(desde))),
                  ],
                  data: (dias) => [
                    for (final (i, d) in dias.indexed)
                      AparecerEnCascada(
                        key: ValueKey('${d.fecha}-$i'),
                        indice: i,
                        child: _Dia(dia: d, alCambiar: () => ref.invalidate(semanaProvider(desde))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja flotante de vidrio con lo que hay en un día: sus citas (con notas) y bloqueos, y «Reservar en este día».
Future<void> mostrarHojaDia(BuildContext context, DateTime dia) =>
    mostrarHojaVidrio<void>(context, builder: (_) => _HojaDia(dia: dia));

class _HojaDia extends ConsumerWidget {
  const _HojaDia({required this.dia});

  final DateTime dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = Fechas.fechaApi(dia);
    final datos = ref.watch(semanaProvider(clave));
    final titulo = Fechas.diaLargo(clave);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo[0].toUpperCase() + titulo.substring(1), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Flexible(
            child: datos.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Cargando()),
              error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(semanaProvider(clave))),
              data: (dias) {
                final d = dias.isEmpty ? null : dias.first;
                if (d == null || (d.citas.isEmpty && d.bloqueos.isEmpty)) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Vacio('Día libre: aún no hay citas.'),
                  );
                }
                return SingleChildScrollView(
                  child: _Dia(dia: d, alCambiar: () => ref.invalidate(semanaProvider(clave)), sinTitulo: true),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              abrirReservaRapida(context, ref, dia: dia);
            },
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Reservar en este día'),
          ),
        ],
      ),
    );
  }
}

class _Dia extends ConsumerWidget {
  const _Dia({required this.dia, required this.alCambiar, this.sinTitulo = false});

  final DiaSemana dia;
  final VoidCallback alCambiar;
  final bool sinTitulo;

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
          if (!sinTitulo)
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
