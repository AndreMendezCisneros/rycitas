import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../core/tema.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';
import '../citas/acciones_cita.dart';
import 'agenda_controlador.dart';

class HoyPantalla extends ConsumerWidget {
  const HoyPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(agendaProvider);
    final datos = estado.value;
    final negocio = ref.watch(negocioActualProvider);
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              datos == null ? 'Hoy' : _titulo(datos.agenda.fecha),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (negocio.nombre.isNotEmpty)
              Text(negocio.nombre, style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
          ],
        ),
        actions: [
          const FiltroProfesional(),
          IconButton.filledTonal(
            tooltip: 'Recordatorios',
            onPressed: () => context.push('/recordatorios'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: datos == null || datos.sinConexion
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/nueva-cita'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva cita'),
            ),
      body: datos != null
          ? _Contenido(estado: datos)
          : estado.hasError
          ? ErrorConReintento(error: estado.error!, alReintentar: () => ref.invalidate(agendaProvider))
          : const Cargando(),
      bottomNavigationBar: datos == null || datos.sinConexion ? null : _PanelConsulta(agenda: datos.agenda),
    );
  }

  /// «Sábado 7 nov»: corto para que quepa junto al filtro y la campana.
  String _titulo(String fecha) {
    final texto = DateFormat("EEEE d MMM", 'es').format(DateTime.parse(fecha)).replaceAll('.', '');
    return texto[0].toUpperCase() + texto.substring(1);
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.estado});

  final EstadoAgenda estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = estado.agenda;
    final filas = _porTurno(agenda);
    final atendidas = agenda.citas.where((c) => c.estado == 'terminada').length;
    final activas = agenda.citas.where((c) => !c.porAprobar).length;
    return RefreshIndicator(
      onRefresh: () => ref.read(agendaProvider.notifier).refrescar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        children: [
          if (estado.sinConexion)
            const _Franja(
              texto: 'Sin conexión. Esta es la última agenda guardada; solo se puede consultar.',
              icono: Icons.cloud_off_rounded,
            ),
          if (agenda.retrasoMin > 0)
            _Franja(
              texto: 'Vas con ${agenda.retrasoMin} min de retraso.',
              icono: Icons.schedule_rounded,
              key: const Key('retraso'),
            ),
          if (agenda.porAprobar > 0) _AvisoPorConfirmar(cantidad: agenda.porAprobar),
          if (agenda.citas.isNotEmpty || agenda.huecos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TarjetaDato(
                      valor: '$activas',
                      etiqueta: activas == 1 ? 'cita' : 'citas',
                      icono: Icons.event_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TarjetaDato(
                      valor: '$atendidas',
                      etiqueta: atendidas == 1 ? 'atendida' : 'atendidas',
                      icono: Icons.task_alt_rounded,
                      color: colorExito,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TarjetaDato(
                      valor: '${agenda.huecos.length}',
                      etiqueta: agenda.huecos.length == 1 ? 'libre' : 'libres',
                      icono: Icons.more_time_rounded,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
            ),
          if (filas.isEmpty)
            const Vacio('No hay citas ni horario de atención para hoy.', icono: Icons.wb_sunny_outlined),
          ...filas,
        ],
      ),
    );
  }

  List<Widget> _ordenar(Iterable<Cita> citas, Iterable<Hueco> huecos) {
    final elementos = <(DateTime, Widget)>[
      for (final c in citas)
        (DateTime.parse(c.inicioEstimado ?? c.inicio), _TarjetaCita(cita: c, soloLectura: estado.sinConexion)),
      for (final h in huecos) (DateTime.parse(h.inicio), _FilaHueco(hueco: h)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in elementos) e.$2];
  }

  /// La agenda dividida en los turnos del negocio. En cada turno, primero lo que falta confirmar.
  List<Widget> _porTurno(Agenda agenda) {
    final turnos = agenda.turnos;
    if (turnos.length < 2) return _ordenar(agenda.citas, agenda.huecos);
    int minuto(String iso) {
      final t = Fechas.enLima(iso);
      return t.hour * 60 + t.minute;
    }

    Turno de(String iso) => turnos.firstWhere((t) => t.contiene(minuto(iso)), orElse: () => turnos.last);
    final ahora = Fechas.ahora();
    final esHoy = Fechas.fechaApi(ahora) == agenda.fecha;
    final minutoAhora = ahora.hour * 60 + ahora.minute;
    final secciones = <Widget>[];
    for (final turno in turnos) {
      final citas = agenda.citas.where((c) => de(c.inicio) == turno).toList();
      final huecos = agenda.huecos.where((h) => de(h.inicio) == turno).toList();
      if (citas.isEmpty && huecos.isEmpty) continue;
      final porConfirmar = citas.where((c) => c.porAprobar).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
      final resto = citas.where((c) => !c.porAprobar).toList();
      secciones.add(
        _SeccionTurno(
          key: Key('turno-${turno.nombre}'),
          turno: turno,
          citas: resto.length,
          porConfirmar: porConfirmar.length,
          // Los turnos que ya terminaron hoy empiezan plegados: lo que importa es lo que viene.
          plegado: esHoy && minutoAhora >= turno.hasta && porConfirmar.isEmpty,
          hijos: [
            if (porConfirmar.isNotEmpty) ...[
              const _SubtituloTurno('Por confirmar'),
              for (final c in porConfirmar) _TarjetaCita(cita: c, soloLectura: estado.sinConexion),
              if (resto.isNotEmpty || huecos.isNotEmpty) const _SubtituloTurno('Agenda'),
            ],
            ..._ordenar(resto, huecos),
          ],
        ),
      );
    }
    return secciones;
  }
}

String _hhmm(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

/// «Turno mañana · hasta las 13:00», con cuántas citas tiene y cuántas faltan confirmar. Se pliega con un toque.
class _SeccionTurno extends StatefulWidget {
  const _SeccionTurno({
    super.key,
    required this.turno,
    required this.citas,
    required this.porConfirmar,
    required this.plegado,
    required this.hijos,
  });

  final Turno turno;
  final int citas;
  final int porConfirmar;
  final bool plegado;
  final List<Widget> hijos;

  @override
  State<_SeccionTurno> createState() => _SeccionTurnoState();
}

class _SeccionTurnoState extends State<_SeccionTurno> {
  late bool _abierto = !widget.plegado;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final t = widget.turno;
    final rango = t.desde == 0
        ? 'hasta las ${_hhmm(t.hasta)}'
        : t.hasta >= 24 * 60
        ? 'desde las ${_hhmm(t.desde)}'
        : '${_hhmm(t.desde)} a ${_hhmm(t.hasta)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _abierto = !_abierto),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turno ${t.nombre.toLowerCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(rango, style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                    ],
                  ),
                ),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Pastilla(
                        texto: '${widget.citas} ${widget.citas == 1 ? 'cita' : 'citas'}',
                        fondo: esquema.surfaceContainerHigh,
                        color: esquema.onSurface,
                      ),
                      if (widget.porConfirmar > 0)
                        _Pastilla(
                          key: Key('turno-${t.nombre}-por-confirmar'),
                          texto: '${widget.porConfirmar} por confirmar',
                          fondo: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          color: const Color(0xFFB45309),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(_abierto ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: esquema.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (_abierto) ...widget.hijos,
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({super.key, required this.texto, required this.fondo, required this.color});

  final String texto;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
    child: Text(
      texto,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _SubtituloTurno extends StatelessWidget {
  const _SubtituloTurno(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
    child: Text(
      texto.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Las reservas web esperan respuesta: es lo primero que hay que ver al abrir la app.
class _AvisoPorConfirmar extends StatelessWidget {
  const _AvisoPorConfirmar({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    const ambar = Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ambar.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const Key('por-confirmar'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/por-aprobar'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: ambar, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.pending_actions_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cantidad == 1 ? '1 reserva por confirmar' : '$cantidad reservas por confirmar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('Confirma y avisa por WhatsApp', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Franja extends StatelessWidget {
  const _Franja({required this.texto, required this.icono, super.key});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: colorAviso, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Icon(icono, color: colorAvisoTexto, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: colorAvisoTexto, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Columna de la hora con el punto y la línea de la línea de tiempo.
class _Linea extends StatelessWidget {
  const _Linea({required this.hora, required this.color, required this.child, this.tachada});

  final String hora;
  final String? tachada;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hora, style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  if (tachada != null)
                    Text(
                      tachada!,
                      style: textos.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)],
                  ),
                ),
                Expanded(child: Container(width: 2, color: esquema.outlineVariant.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
          ),
        ],
      ),
    );
  }
}

class _FilaHueco extends StatelessWidget {
  const _FilaHueco({required this.hueco});

  final Hueco hueco;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return _Linea(
      hora: Fechas.hora(hueco.inicio),
      color: esquema.outlineVariant,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: esquema.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Icon(Icons.more_time_rounded, size: 18, color: esquema.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Libre ${Fechas.hora(hueco.inicio)} a ${Fechas.hora(hueco.fin)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: esquema.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCita extends ConsumerWidget {
  const _TarjetaCita({required this.cita, required this.soloLectura});

  final Cita cita;
  final bool soloLectura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final negocio = ref.watch(negocioActualProvider);
    // La cuenta general ve a todos: cada cita dice con quién es. La de un profesional solo ve las suyas.
    final verQuien = negocio.porProfesional && negocio.esGeneral;
    final estimada = cita.inicioEstimado;
    final movida = estimada != null && cita.retrasoMin > 0 && !cita.cerrada;
    final color = ColoresEstado.de(cita.estado, esquema);
    final apagada = cita.cerrada;
    return _Linea(
      hora: Fechas.hora(movida ? estimada : cita.inicio),
      tachada: movida ? Fechas.hora(cita.inicio) : null,
      color: color,
      child: Opacity(
        opacity: apagada ? 0.6 : 1,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: cita.enCurso ? const BorderSide(color: colorExito, width: 2) : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: soloLectura ? null : () => mostrarAccionesCita(context, ref, cita),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(cita.paciente.nombre, radio: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cita.paciente.nombre,
                          style: textos.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cita.tratamiento.nombre,
                          style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                        ),
                        if (verQuien && cita.profesional != null)
                          Text('Con ${cita.profesional!.nombre}', style: textos.bodySmall),
                        if (cita.precioTexto != null && cita.porAprobar)
                          Text(cita.precioTexto!, style: textos.bodySmall),
                        if (cita.cupon != null)
                          Text(
                            'Cupón ${cita.cupon!.codigo} · ${cita.cupon!.descuento}',
                            key: Key('cupon-cita-${cita.id}'),
                            style: textos.bodySmall?.copyWith(color: esquema.tertiary, fontWeight: FontWeight.w600),
                          ),
                        if (cita.llego && !cita.cerrada && !cita.enCurso)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Llegó ${Fechas.hora(cita.llegadaEn!)}',
                              key: Key('llego-${cita.id}'),
                              style: textos.bodySmall?.copyWith(color: colorExito, fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (cita.paciente.inasistencias > 0)
                          Text(
                            '${cita.paciente.inasistencias} inasistencia${cita.paciente.inasistencias == 1 ? '' : 's'}',
                            style: textos.bodySmall?.copyWith(color: colorAvisoTexto, fontWeight: FontWeight.w600),
                          ),
                        const SizedBox(height: 8),
                        ChipEstado(estado: cita.estado, texto: cita.estadoTexto),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo que hay que hacer ahora, abajo y al alcance del pulgar: cada acción a un toque (RNF-10).
class _PanelConsulta extends ConsumerWidget {
  const _PanelConsulta({required this.agenda});

  final Agenda agenda;

  Future<void> _hacer(BuildContext context, WidgetRef ref, AccionConsulta accion, Cita cita) async {
    var siguientes = <Siguiente>[];
    final error = await ref
        .read(agendaProvider.notifier)
        .accion(accion, cita.id, alResponder: (datos) => siguientes = siguientesDe(datos));
    if (!context.mounted) return;
    if (error != null) return avisar(context, error);
    // Tras «No vino» queda un hueco: se ofrece avisar a los siguientes pacientes.
    if (siguientes.isEmpty) return;
    await ofrecerAviso(context, '${cita.paciente.nombre} no vino', null, siguientes: siguientes);
  }

  Future<void> _demorar(BuildContext context, WidgetRef ref, Cita cita) async {
    final minutos = await elegirDemora(context);
    if (minutos == null || !context.mounted) return;
    final (error, avisos) = await ref.read(agendaProvider.notifier).demorar(cita.id, minutos);
    if (!context.mounted) return;
    if (error != null) return avisar(context, error);
    await mostrarAvisosDemora(context, minutos, avisos);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enCurso = agenda.citas.where((c) => c.enCurso).firstOrNull;
    final siguiente = agenda.citas.where((c) => c.programada).firstOrNull;
    final cita = enCurso ?? siguiente;
    if (cita == null) return const SizedBox.shrink();
    // «No vino» recién a los N min de la hora: antes, el cliente todavía puede llegar (el servidor también lo valida).
    final tolerancia = ref.watch(negocioActualProvider.select((n) => n.toleranciaInasistenciaMin));
    final noVinoDesde = Fechas.enLima(cita.inicio).add(Duration(minutes: tolerancia));
    final puedeNoVino = !cita.llego && !Fechas.ahora().isBefore(noVinoDesde);

    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(cita.paciente.nombre, radio: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cita.enCurso ? 'Atendiendo a' : 'Sigue'} ${cita.paciente.nombre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.titleMedium,
                        ),
                        Text(
                          [
                            cita.tratamiento.nombre,
                            if (cita.enCurso && cita.inicioReal != null)
                              'desde ${Fechas.hora(cita.inicioReal!)}'
                            else
                              Fechas.hora(cita.inicio),
                            if (!cita.enCurso && cita.llego) 'llegó ${Fechas.hora(cita.llegadaEn!)}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.bodySmall?.copyWith(
                            color: cita.enCurso || cita.llego ? colorExito : esquema.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avisar a los que esperan, antes o durante la atención.
                  TextButton.icon(
                    key: const Key('me-demoro'),
                    onPressed: () => _demorar(context, ref, cita),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Me demoro'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (cita.enCurso)
                FilledButton(
                  onPressed: () => _hacer(context, ref, AccionConsulta.terminar, cita),
                  child: const Text('Terminar'),
                )
              else if (cita.llego)
                // Ya llegó: «Iniciar» mide la duración; «Atendida» la cierra sin cronómetro (ambas cuentan asistencia).
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('atendida'),
                        onPressed: () => _hacer(context, ref, AccionConsulta.terminar, cita),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Atendida')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => _hacer(context, ref, AccionConsulta.iniciar, cita),
                        child: const Text('Iniciar'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    if (!cita.llego) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('llego'),
                          onPressed: () => _hacer(context, ref, AccionConsulta.llego, cita),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Llegó')),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!cita.llego)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('no-vino'),
                          onPressed: !puedeNoVino
                              ? null
                              : () async {
                                  // Único paso con confirmación: suma una inasistencia que no se puede deshacer.
                                  final ok = await confirmar(
                                    context,
                                    '¿No vino ${cita.paciente.nombre}?',
                                    'Se sumará una inasistencia a su historial.',
                                    accion: 'No vino',
                                  );
                                  if (ok && context.mounted) await _hacer(context, ref, AccionConsulta.noAsistio, cita);
                                },
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              puedeNoVino ? 'No vino' : 'No vino (${Fechas.hora(noVinoDesde.toIso8601String())})',
                            ),
                          ),
                        ),
                      ),
                    if (!cita.llego) const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => _hacer(context, ref, AccionConsulta.iniciar, cita),
                        child: const Text('Iniciar'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «¿De quién?»: solo aparece si el negocio tiene varios profesionales con agenda propia.
class FiltroProfesional extends ConsumerWidget {
  const FiltroProfesional({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negocio = ref.watch(negocioActualProvider);
    // Solo la cuenta general elige de quién ver la agenda: la de un profesional siempre ve la suya.
    if (!negocio.porProfesional || !negocio.esGeneral) return const SizedBox.shrink();
    final filtro = ref.watch(filtroProfesionalProvider);
    final voc = negocio.voc;
    final mio = negocio.miProfesionalId;
    String nombre(int? id) {
      if (id == null) return mio == null ? 'Todos' : 'Mi agenda';
      if (id == 0) return 'Todos';
      return negocio.profesionales.where((p) => p.id == id).firstOrNull?.nombre ?? 'Todos';
    }

    return PopupMenuButton<int>(
      key: const Key('filtro-profesional'),
      tooltip: 'Ver la agenda de un ${voc.profesional}',
      initialValue: filtro ?? (mio ?? 0),
      onSelected: (id) => ref.read(filtroProfesionalProvider.notifier).state = id == (mio ?? 0) ? null : id,
      itemBuilder: (_) => [
        if (mio != null) PopupMenuItem(value: mio, child: const Text('Mi agenda')),
        const PopupMenuItem(value: 0, child: Text('Todos')),
        for (final p in negocio.profesionales)
          if (p.id != mio) PopupMenuItem(value: p.id, child: Text(p.nombre)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [const Icon(Icons.people_alt_outlined), const SizedBox(width: 4), Text(nombre(filtro))],
        ),
      ),
    );
  }
}
