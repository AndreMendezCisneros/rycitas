import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/tema.dart';
import '../../shared/comunes.dart';
import '../../shared/diseno/calendario.dart';
import '../../shared/diseno/movimiento.dart';
import '../../shared/diseno/notas.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import 'datos_cliente.dart';
import 'gamificacion.dart';
import 'inicio_cliente.dart';
import 'lugares_hoja.dart';
import 'mascota.dart';
import 'widgets_cliente.dart';
import '../../shared/diseno/tonos.dart';

/// «Mis citas»: Próximas, Historial (todas las anteriores, de 20 en 20) y Calendario. Tocar una cita abre sus
/// detalles en una hoja flotante. Cancelar o mover lo hace el negocio: se le escribe.
class MisCitasPantalla extends ConsumerStatefulWidget {
  const MisCitasPantalla({super.key, this.citaInicial});

  /// Al llegar desde una notificación: se abre el detalle de esa cita.
  final String? citaInicial;

  @override
  ConsumerState<MisCitasPantalla> createState() => _MisCitasPantallaState();
}

enum VistaCitas { proximas, historial, calendario }

class _MisCitasPantallaState extends ConsumerState<MisCitasPantalla> {
  /// Sin elegir: Próximas si tiene alguna; si no, el Historial.
  VistaCitas? _vista;
  late DateTime _mes = DateTime(Fechas.ahora().year, Fechas.ahora().month);
  DateTime? _elegido;
  String? _abierta;

  @override
  void didUpdateWidget(MisCitasPantalla viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.citaInicial != widget.citaInicial) _abierta = null;
  }

  /// Abre la cita de la notificación una sola vez, cuando ya llegaron los datos.
  void _abrirInicial(List<Json> todas) {
    final id = widget.citaInicial;
    if (id == null || _abierta == id) return;
    final cita = todas.where((c) => '${c['id']}' == id).firstOrNull;
    if (cita == null) return;
    _abierta = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final inicio = Fechas.enLima(cita['inicio'] as String);
      setState(() {
        _mes = DateTime(inicio.year, inicio.month);
        _elegido = DateTime(inicio.year, inicio.month, inicio.day);
      });
      mostrarDetalleCita(context, cita);
    });
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(misCitasProvider);
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: FondoManchas(
        intensidad: 0.6,
        child: SafeArea(
          bottom: false,
          child: datos.when(
            loading: () => const Cargando(),
            error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(misCitasProvider)),
            data: (d) {
              final proximas = lista(d['proximas']);
              final pasadas = lista(d['pasadas']);
              final todas = [...proximas, ...pasadas];
              final vista =
                  _vista ?? (proximas.isEmpty && pasadas.isNotEmpty ? VistaCitas.historial : VistaCitas.proximas);
              _abrirInicial(todas);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(misCitasProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text('Mis citas', style: textos.headlineMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<VistaCitas>(
                      key: const Key('vista-citas'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: VistaCitas.proximas, label: Text('Próximas')),
                        ButtonSegment(value: VistaCitas.historial, label: Text('Historial')),
                        ButtonSegment(value: VistaCitas.calendario, label: Text('Calendario')),
                      ],
                      selected: {vista},
                      onSelectionChanged: (v) => setState(() => _vista = v.first),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: sinEfectos(context) ? Duration.zero : const Duration(milliseconds: 300),
                      child: switch (vista) {
                        VistaCitas.proximas => _Proximas(key: const ValueKey('proximas'), proximas: proximas),
                        VistaCitas.historial => const HistorialCitas(key: ValueKey('historial')),
                        VistaCitas.calendario => _calendario(todas),
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _calendario(List<Json> todas) {
    final porDia = <String, List<Json>>{};
    for (final c in todas) {
      porDia.putIfAbsent(fechaClave(Fechas.enLima(c['inicio'] as String)), () => []).add(c);
    }
    final marcas = {
      for (final MapEntry(key: dia, value: citas) in porDia.entries)
        dia: MarcaDia(
          citas: citas.length,
          colores: [for (final c in citas) ColoresEstado.de(c['estado'] as String, Theme.of(context).colorScheme)],
        ),
    };
    return Column(
      key: const ValueKey('calendario'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Vidrio(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: CalendarioMes(
            mes: _mes,
            hoy: Fechas.ahora(),
            seleccionado: _elegido,
            marcas: marcas,
            alCambiarMes: (paso) => setState(() => _mes = DateTime(_mes.year, _mes.month + paso)),
            alTocarDia: (dia) {
              setState(() => _elegido = dia);
              final citas = porDia[fechaClave(dia)] ?? const [];
              if (citas.length == 1) {
                mostrarDetalleCita(context, citas.first);
              } else {
                _mostrarDia(dia, citas);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        LeyendaCalendario(
          items: [(context.tonos.acento, 'Confirmada'), (Paleta.ambar, 'Por confirmar'), (Paleta.gris, 'Pasada')],
        ),
        if (todas.isEmpty) ...[
          const SizedBox(height: 16),
          const AvisoSuave(
            icono: Icons.event_note_rounded,
            texto: 'Todavía no tienes citas. Toca un día para reservar la primera.',
          ),
        ],
      ],
    );
  }

  void _mostrarDia(DateTime dia, List<Json> citas) {
    final titulo = DateFormat("EEEE d 'de' MMMM", 'es').format(dia);
    final pasado = dia.isBefore(DateTime(Fechas.ahora().year, Fechas.ahora().month, Fechas.ahora().day));
    mostrarHojaVidrio<void>(
      context,
      builder: (contexto) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        children: [
          Text(titulo[0].toUpperCase() + titulo.substring(1), style: Theme.of(contexto).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (citas.isEmpty)
            Text(
              pasado ? 'No tuviste citas este día.' : 'Este día lo tienes libre.',
              style: TextStyle(color: context.tonos.textoSuave),
            ),
          for (final c in citas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CitaCliente(
                cita: c,
                pasada: !proximaActiva(c),
                alTocar: () {
                  Navigator.pop(contexto);
                  mostrarDetalleCita(context, c);
                },
              ),
            ),
          if (!pasado) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(contexto);
                mostrarLugaresParaReservar(context, dia: dia);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Reservar este día'),
            ),
          ],
        ],
      ),
    );
  }
}

bool proximaActiva(Json c) =>
    const {'por_aprobar', 'programada', 'en_curso'}.contains(c['estado']) &&
    Fechas.enLima(c['fin'] as String? ?? c['inicio'] as String).isAfter(Fechas.ahora());

/// La próxima cita, destacada, con cuenta regresiva.
class ProximaCitaTarjeta extends StatelessWidget {
  const ProximaCitaTarjeta({super.key, required this.cita});

  final Json cita;

  String _faltan() {
    final falta = Fechas.enLima(cita['inicio'] as String).difference(Fechas.ahora());
    if (falta.isNegative) return 'Es ahora';
    if (falta.inMinutes < 60) return 'En ${falta.inMinutes} min';
    if (falta.inHours < 24) return 'En ${falta.inHours} h';
    final dias = falta.inDays;
    return dias == 1 ? 'Mañana' : 'En $dias días';
  }

  @override
  Widget build(BuildContext context) {
    final negocio = cita['negocio'] as Json;
    final textos = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('proxima-${cita['id']}'),
        borderRadius: BorderRadius.circular(26),
        onTap: () => mostrarDetalleCita(context, cita),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: Paleta.degradado,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: context.tonos.acento.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tu próxima cita · ${_faltan()}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(negocio['nombre'] as String, style: textos.titleLarge?.copyWith(color: Colors.white)),
                      Text(
                        '${cita['tratamiento']} · ${Fechas.diaHora(cita['inicio'] as String)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Proximas extends StatelessWidget {
  const _Proximas({super.key, required this.proximas});

  final List<Json> proximas;

  @override
  Widget build(BuildContext context) {
    if (proximas.isEmpty) {
      return const _SinCitas(texto: 'No tienes citas por venir. ¿Te consentimos pronto?');
    }
    var i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProximaCitaTarjeta(cita: proximas.first),
        const SizedBox(height: 16),
        for (final c in proximas.skip(1))
          AparecerEnCascada(
            indice: i++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CitaCliente(cita: c, alTocar: () => mostrarDetalleCita(context, c)),
            ),
          ),
      ],
    );
  }
}

class _SinCitas extends StatelessWidget {
  const _SinCitas({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Rubi(tam: 84, expresion: ExpresionRubi.dormida, etiqueta: 'Rubí descansando'),
        const SizedBox(height: 12),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.tonos.textoSuave),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('buscar-lugar'),
          onPressed: () => mostrarLugaresParaReservar(context),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Buscar un lugar'),
        ),
      ],
    ),
  );
}

/// Todas las citas que ya pasaron, agrupadas por mes, de 20 en 20, con filtro por lugar.
class HistorialCitas extends ConsumerStatefulWidget {
  const HistorialCitas({super.key});

  @override
  ConsumerState<HistorialCitas> createState() => _HistorialCitasState();
}

class _HistorialCitasState extends ConsumerState<HistorialCitas> {
  final _citas = <Json>[];
  List<Json> _negocios = const [];
  int _visitas = 0;
  bool _completo = true;
  bool _hayMas = false;
  bool _cargando = true;
  Object? _error;
  String _negocio = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool mas = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await ref
          .read(apiClienteProvider)
          .get(
            '/mis-citas/historial',
            params: {
              if (_negocio.isNotEmpty) 'negocio': _negocio,
              if (mas && _citas.isNotEmpty) 'antes': _citas.last['inicio'],
            },
          );
      if (!mounted) return;
      setState(() {
        if (!mas) _citas.clear();
        _citas.addAll(lista(d['citas']));
        _hayMas = d['hay_mas'] == true;
        if (d['negocios'] != null && _negocio.isEmpty) _negocios = lista(d['negocios']);
        if (d['visitas'] != null && _negocio.isEmpty) _visitas = d['visitas'] as int;
        if (d['completo'] != null) _completo = d['completo'] == true;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrar(String slug) {
    if (slug == _negocio) return;
    _negocio = slug;
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    if (_error != null && _citas.isEmpty) {
      return ErrorConReintento(error: _error!, alReintentar: _cargar);
    }
    if (_cargando && _citas.isEmpty && _negocios.isEmpty) {
      return const Padding(padding: EdgeInsets.all(32), child: Cargando());
    }
    // Agrupa por mes: «Noviembre 2026».
    final porMes = <String, List<Json>>{};
    for (final c in _citas) {
      final mes = DateFormat('MMMM yyyy', 'es').format(Fechas.enLima(c['inicio'] as String));
      porMes.putIfAbsent(mes[0].toUpperCase() + mes.substring(1), () => []).add(c);
    }
    final opciones = <Json>[
      {'slug': '', 'nombre': 'Todos'},
      ..._negocios,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_completo) const _FaltanCitas(),
        if (_visitas > 0 || _negocios.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '$_visitas ${_visitas == 1 ? 'visita' : 'visitas'} · '
              '${_negocios.length} ${_negocios.length == 1 ? 'lugar' : 'lugares'}',
              key: const Key('resumen-historial'),
              style: textos.titleSmall?.copyWith(color: context.tonos.textoSuave),
            ),
          ),
        if (_negocios.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final n in opciones)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ChoiceChip(
                      key: Key('filtro-${n['slug'] == '' ? 'todos' : n['slug']}'),
                      label: Text(n['nombre'] as String),
                      selected: _negocio == n['slug'],
                      onSelected: (_) => _filtrar(n['slug'] as String),
                    ),
                  ),
              ],
            ),
          ),
        if (_citas.isEmpty && !_cargando)
          const _SinCitas(texto: 'Aún no tienes visitas. Cuando vayas a un lugar, quedará aquí.'),
        for (final MapEntry(key: mes, value: citas) in porMes.entries) ...[
          TituloGrupo(mes),
          for (final c in citas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CitaCliente(
                cita: c,
                pasada: true,
                alTocar: () => mostrarDetalleCita(context, c),
                accion: c['estado'] == 'terminada'
                    ? TextButton.icon(
                        key: Key('reservar-de-nuevo-${c['id']}'),
                        onPressed: () => context.push(
                          '/cliente/negocio/${(c['negocio'] as Json)['slug']}/reservar/${c['tratamiento_slug']}',
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('Reservar de nuevo'),
                      )
                    : null,
              ),
            ),
        ],
        if (_hayMas)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OutlinedButton(
              key: const Key('historial-ver-mas'),
              onPressed: _cargando ? null : () => _cargar(mas: true),
              child: Text(_cargando ? 'Cargando…' : 'Ver más'),
            ),
          ),
      ],
    );
  }
}

/// Sin el WhatsApp probado solo se ven las citas reservadas desde la app: se explica cómo traer las demás.
class _FaltanCitas extends ConsumerWidget {
  const _FaltanCitas();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    key: const Key('faltan-citas'),
    color: context.tonos.ambarFondo,
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Faltan citas?',
            style: TextStyle(fontWeight: FontWeight.w800, color: context.tonos.ambarTexto),
          ),
          const SizedBox(height: 4),
          Text(
            'Aquí está lo que reservaste en la app. Las citas que hiciste por WhatsApp o en la web aparecen al pegar '
            'el enlace que te mandó el negocio.',
            style: TextStyle(color: context.tonos.ambarTexto),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => vincularConEnlace(context, ref),
            icon: const Icon(Icons.link_rounded),
            label: const Text('Pegar el enlace de mi cita'),
          ),
        ],
      ),
    ),
  );
}

class _CitaCliente extends StatelessWidget {
  const _CitaCliente({required this.cita, this.pasada = false, required this.alTocar, this.accion});

  final Json cita;
  final bool pasada;
  final VoidCallback alTocar;

  /// Por ejemplo «Reservar de nuevo» en el historial.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final negocio = cita['negocio'] as Json;
    final inicio = Fechas.enLima(cita['inicio'] as String);
    final color = ColoresEstado.de(cita['estado'] as String, Theme.of(context).colorScheme);
    final notas = (cita['notas'] as String? ?? '').trim();
    return Card(
      key: Key('cita-cliente-${cita['id']}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: pasada ? context.tonos.superficieSuave : context.tonos.rosa,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM', 'es').format(inicio).toUpperCase().replaceAll('.', ''),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: pasada ? context.tonos.textoSuave : context.tonos.acento,
                      ),
                    ),
                    Text(
                      '${inicio.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: pasada ? context.tonos.textoSuave : context.tonos.acentoFuerte,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(negocio['nombre'] as String, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      [
                        cita['tratamiento'],
                        Fechas.hora(cita['inicio'] as String),
                        if ((cita['precio_texto'] as String? ?? '').isNotEmpty) cita['precio_texto'],
                      ].join(' · '),
                      style: TextStyle(color: context.tonos.textoSuave),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cita['estado_texto'] as String,
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ],
                    ),
                    if (notas.isNotEmpty) NotaCita(notas, compacta: true),
                    if (accion != null) Align(alignment: Alignment.centerLeft, child: accion),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja flotante con todo sobre una cita: dónde, cuándo, con quién, lo que pidió (notas) y qué puede hacer.
Future<void> mostrarDetalleCita(BuildContext context, Json cita) =>
    mostrarHojaVidrio<void>(context, builder: (_) => DetalleCitaCliente(cita: cita));

class DetalleCitaCliente extends StatelessWidget {
  const DetalleCitaCliente({super.key, required this.cita});

  final Json cita;

  @override
  Widget build(BuildContext context) {
    final negocio = cita['negocio'] as Json;
    final lugar = cita['consultorio'] as Json;
    final cupon = cita['cupon'] as Json?;
    final whatsapp = lugar['whatsapp'] as String? ?? '';
    final activa = proximaActiva(cita);
    final notas = (cita['notas'] as String? ?? '').trim();
    final textos = Theme.of(context).textTheme;
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(Fechas.enLima(cita['inicio'] as String));
    final texto =
        'Hola, soy ${cita['paciente']}. Sobre mi cita de ${cita['tratamiento']} del '
        '${Fechas.diaHora(cita['inicio'] as String)}: ';
    Widget fila(IconData icono, String titulo, String valor) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.tonos.rosa, borderRadius: BorderRadius.circular(12)),
            child: Icon(icono, size: 18, color: context.tonos.acento),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.labelMedium?.copyWith(color: context.tonos.textoSuave)),
                Text(valor, style: textos.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
    return ListView(
      key: Key('detalle-cita-${cita['id']}'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Row(
          children: [
            Expanded(child: Text(negocio['nombre'] as String, style: textos.titleLarge)),
            ChipEstado(estado: cita['estado'] as String, texto: cita['estado_texto'] as String),
          ],
        ),
        const SizedBox(height: 16),
        fila(
          Icons.event_rounded,
          'Cuándo',
          '${fecha[0].toUpperCase()}${fecha.substring(1)}, ${Fechas.hora(cita['inicio'] as String)}',
        ),
        fila(Icons.spa_rounded, 'Servicio', '${cita['tratamiento']}'),
        fila(Icons.person_rounded, 'Con', '${cita['profesional']}'),
        if ((lugar['direccion'] as String? ?? '').isNotEmpty)
          fila(Icons.place_rounded, 'Dónde', lugar['direccion'] as String),
        if (cita['hora_estimada'] != null && (cita['retraso_min'] as int? ?? 0) > 0)
          fila(
            Icons.schedule_rounded,
            'Van con ${cita['retraso_min']} min de retraso',
            'Te atienden cerca de las ${Fechas.hora(cita['hora_estimada'] as String)}',
          ),
        if (cupon != null) fila(Icons.local_offer_rounded, 'Cupón', '${cupon['codigo']} · ${cupon['descuento']}'),
        if (notas.isNotEmpty) ...[
          Text('Lo que pediste', style: textos.labelMedium?.copyWith(color: context.tonos.textoSuave)),
          NotaCita(notas),
          const SizedBox(height: 12),
        ],
        if (cita['estado'] == 'por_aprobar')
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.tonos.ambarFondo, borderRadius: BorderRadius.circular(14)),
            child: Text(
              'El lugar aún debe confirmar tu reserva. Te avisaremos con una notificación.',
              style: TextStyle(color: context.tonos.ambarTexto, fontWeight: FontWeight.w600),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!activa)
              ActionChip(
                avatar: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Volver a reservar'),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/cliente/negocio/${negocio['slug']}');
                },
              ),
            if (activa && (lugar['mapa_url'] as String? ?? '').isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Cómo llegar'),
                onPressed: () => abrirEnlace(context, lugar['mapa_url'] as String),
              ),
            if (activa && whatsapp.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Escribir'),
                onPressed: () => abrirWhatsapp(context, 'https://wa.me/$whatsapp?text=${Uri.encodeComponent(texto)}'),
              ),
            if (activa)
              ActionChip(
                avatar: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Calendario y más'),
                onPressed: () => abrirEnlace(context, '$apiUrl${cita['enlace']}'),
              ),
          ],
        ),
      ],
    );
  }
}

/// «Beneficios»: tarjetas de sellos, cupones y el código para invitar.
class BeneficiosPantalla extends ConsumerWidget {
  const BeneficiosPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(beneficiosProvider);
    return Scaffold(
      body: FondoManchas(
        intensidad: 0.6,
        child: SafeArea(
          bottom: false,
          child: datos.when(
            loading: () => const Cargando(),
            error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(beneficiosProvider)),
            data: (d) {
              final tarjetas = lista(d['tarjetas']);
              final cupones = lista(d['cupones']);
              return RefreshIndicator(
                onRefresh: () async => refrescarCliente(ref),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text('Beneficios', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 14),
                    const TarjetaProgreso(),
                    const SizedBox(height: 18),
                    const SeccionLogros(),
                    if (cupones.isNotEmpty) const TituloGrupo('Cupones'),
                    for (final c in cupones)
                      TarjetaCupon(
                        cupon: c,
                        negocio: (c['negocio'] as Json)['nombre'] as String,
                        alUsar: () => context.push('/cliente/negocio/${(c['negocio'] as Json)['slug']}'),
                      ),
                    if (tarjetas.isNotEmpty) const TituloGrupo('Tarjetas de sellos'),
                    for (final t in tarjetas)
                      TarjetaSellos(tarjeta: t, negocio: (t['negocio'] as Json)['nombre'] as String),
                    if (tarjetas.isEmpty && cupones.isEmpty)
                      const AvisoSuave(
                        icono: Icons.loyalty_rounded,
                        texto:
                            'Cuando un lugar donde te atiendes tenga tarjeta de sellos o te mande un cupón, lo verás aquí.',
                      ),
                    const SizedBox(height: 8),
                    TarjetaInvitar(codigo: d['codigo_referido'] as String),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
