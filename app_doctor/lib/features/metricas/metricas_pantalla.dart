import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';

class Indicadores {
  const Indicadores(this.d);

  final Map<String, dynamic> d;

  int get citas => (d['citas'] as num?)?.toInt() ?? 0;
  int get porConfirmar => (d['por_confirmar'] as num?)?.toInt() ?? 0;
  num? valor(String clave) => d[clave] as num?;
  int entero(String clave) => (d[clave] as num?)?.toInt() ?? 0;
  List<Map<String, dynamic>> get porServicio => [
    for (final f in (d['duracion_por_servicio'] as List? ?? const [])) (f as Map).cast<String, dynamic>(),
  ];
}

class Metricas {
  const Metricas({required this.actual, required this.anterior});

  factory Metricas.fromJson(Map<String, dynamic> j) => Metricas(
    actual: Indicadores((j['actual'] as Map).cast<String, dynamic>()),
    anterior: Indicadores((j['anterior'] as Map).cast<String, dynamic>()),
  );

  final Indicadores actual;
  final Indicadores anterior;
}

final metricasProvider = FutureProvider.autoDispose.family<Metricas, (int, int)>((ref, mes) async {
  final datos = await ref.read(apiProvider).get('/metricas', params: {'anio': mes.$1, 'mes': mes.$2});
  return Metricas.fromJson(datos);
});

/// Tablero «Mi mes» (mejora 9 del análisis): lo que funciona y lo que no, comparado con el mes anterior.
class MetricasPantalla extends ConsumerStatefulWidget {
  const MetricasPantalla({super.key});

  @override
  ConsumerState<MetricasPantalla> createState() => _MetricasPantallaState();
}

class _MetricasPantallaState extends ConsumerState<MetricasPantalla> {
  late DateTime _mes = DateTime(Fechas.ahora().year, Fechas.ahora().month);

  @override
  Widget build(BuildContext context) {
    final clave = (_mes.year, _mes.month);
    final datos = ref.watch(metricasProvider(clave));
    final voc = ref.watch(vocProvider);
    final titulo = DateFormat('MMMM yyyy', 'es').format(_mes);
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi mes · ${titulo[0].toUpperCase()}${titulo.substring(1)}'),
        actions: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(metricasProvider(clave))),
        data: (m) {
          final a = m.actual;
          final b = m.anterior;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (a.porConfirmar > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      a.porConfirmar == 1
                          ? '1 reserva espera tu respuesta.'
                          : '${a.porConfirmar} reservas esperan tu respuesta.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              _Fila('Citas', '${a.citas}', anterior: '${b.citas}', key: const Key('kpi-citas')),
              _Fila(
                'Reservas web confirmadas',
                _pct(a.valor('confirmacion_pct')),
                anterior: _pct(b.valor('confirmacion_pct')),
              ),
              _Fila(
                'Inasistencias',
                _pct(a.valor('inasistencia_pct')),
                anterior: _pct(b.valor('inasistencia_pct')),
                ayuda: 'De las citas que llegaron a su hora.',
              ),
              _Fila(
                'Asistieron',
                '${a.entero('atendidas')} de ${a.entero('atendidas') + a.entero('no_vinieron')}',
                anterior: '${b.entero('atendidas')} de ${b.entero('atendidas') + b.entero('no_vinieron')}',
                ayuda: 'Cuenta «Llegó», «Iniciar» o «Atendida». No vinieron: ${a.entero('no_vinieron')}.',
                key: const Key('kpi-asistieron'),
              ),
              _Fila(
                'Duración real de una cita',
                _min(a.valor('duracion_real_mediana_min')),
                anterior: _min(b.valor('duracion_real_mediana_min')),
                ayuda: 'Mediana entre «Iniciar» y «Terminar» (${a.entero('cronometradas')} citas medidas).',
                key: const Key('kpi-duracion'),
              ),
              _Fila(
                'Empiezas después de la hora',
                _min(a.valor('inicio_tarde_mediana_min')),
                anterior: _min(b.valor('inicio_tarde_mediana_min')),
                ayuda:
                    'Mediana entre la hora de la cita e «Iniciar». '
                    'Avisaste demora en ${a.entero('citas_con_demora')} citas.',
              ),
              if (a.porServicio.isNotEmpty) _DuracionPorServicio(a.porServicio),
              _Fila('Ocupación del horario', _pct(a.valor('ocupacion_pct')), anterior: _pct(b.valor('ocupacion_pct'))),
              _Fila(
                'Tiempo para confirmar',
                _min(a.valor('respuesta_mediana_min')),
                anterior: _min(b.valor('respuesta_mediana_min')),
                ayuda: 'Mediana desde que llega la reserva hasta que la confirmas.',
              ),
              _Fila(
                'Espera en ${voc.elLocal}',
                _min(a.valor('espera_mediana_min')),
                anterior: _min(b.valor('espera_mediana_min')),
                ayuda: 'Mediana entre «Llegó» e «Iniciar».',
              ),
              _Fila(
                '${Vocabulario.may(voc.clientes)} que vuelven',
                _pct(a.valor('vuelven_pct')),
                anterior: _pct(b.valor('vuelven_pct')),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _pct(num? v) => v == null ? '—' : '${v.round()} %';
  static String _min(num? v) => v == null ? '—' : '${v.round()} min';
}

class _Fila extends StatelessWidget {
  const _Fila(this.titulo, this.valor, {required this.anterior, this.ayuda, super.key});

  final String titulo;
  final String valor;
  final String anterior;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    // Los porcentajes llevan además una barra: se leen de un vistazo.
    final porcentaje = valor.endsWith('%') ? (int.tryParse(valor.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) / 100 : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(titulo, style: textos.titleSmall)),
                  Text(
                    valor,
                    style: textos.headlineSmall?.copyWith(color: esquema.primary, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (porcentaje != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: porcentaje.clamp(0, 1).toDouble(),
                    minHeight: 8,
                    backgroundColor: esquema.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: esquema.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('Mes anterior: $anterior', style: textos.labelMedium),
              ),
              if (ayuda != null) ...[
                const SizedBox(height: 6),
                Text(ayuda!, style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que de verdad dura cada servicio frente a lo previsto: sirve para ajustar las duraciones.
class _DuracionPorServicio extends StatelessWidget {
  const _DuracionPorServicio(this.filas);

  final List<Map<String, dynamic>> filas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        key: const Key('kpi-por-servicio'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duración por servicio', style: textos.titleSmall),
              const SizedBox(height: 8),
              for (final f in filas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${f['servicio']} (${f['citas']})', overflow: TextOverflow.ellipsis)),
                      Text(
                        '${f['real_min'] ?? '—'} min',
                        style: textos.titleSmall?.copyWith(color: esquema.primary, fontWeight: FontWeight.w800),
                      ),
                      if (f['prevista_min'] != null)
                        Text('  / ${f['prevista_min']} previstos', style: textos.bodySmall),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Si un servicio dura más de lo previsto, ajusta su duración y la agenda se calculará mejor.',
                style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
