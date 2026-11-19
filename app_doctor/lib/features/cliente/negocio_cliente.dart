import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/diseno/movimiento.dart';
import '../../shared/diseno/notas.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import '../citas/selector_hora.dart';
import 'cambiar_cita.dart';
import 'datos_cliente.dart';
import 'gamificacion.dart';
import 'mascota.dart';
import 'widgets_cliente.dart';
import '../../shared/diseno/tonos.dart';

/// Ficha del lugar: cabecera con su foto, tarjeta de sellos, cupones y servicios para reservar. Si se llega desde el
/// calendario con un día ya elegido ([fecha]), ese día viaja hasta la elección de la hora.
class NegocioClientePantalla extends ConsumerWidget {
  const NegocioClientePantalla({super.key, required this.slug, this.fecha});

  final String slug;
  final String? fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(negocioClienteProvider(slug));
    return Scaffold(
      backgroundColor: context.tonos.fondo,
      body: datos.when(
        loading: () => const SafeArea(child: Cargando()),
        error: (e, _) => SafeArea(
          child: ErrorConReintento(error: e, alReintentar: () => ref.invalidate(negocioClienteProvider(slug))),
        ),
        data: (n) {
          final servicios = lista(n['motivos']);
          final cupones = lista(n['cupones']);
          final tarjeta = n['tarjeta'] as Json?;
          final textos = Theme.of(context).textTheme;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CabeceraDegradado(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Volver',
                            color: Colors.white,
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => context.canPop() ? context.pop() : context.go('/cliente'),
                          ),
                          const Spacer(),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                              child: FotoNegocio(negocio: n, lado: 76),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['nombre'] as String,
                                    style: textos.headlineSmall?.copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(iconoRubro('${n['rubro']}'), size: 16, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${n['rubro_nombre'] ?? ''}',
                                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((n['direccion'] as String? ?? '').isNotEmpty)
                                    Text(
                                      n['direccion'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                sliver: SliverList.list(
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        if ((n['mapa_url'] as String? ?? '').isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Cómo llegar'),
                            onPressed: () => abrirEnlace(context, n['mapa_url'] as String),
                          ),
                        if ((n['whatsapp'] as String? ?? '').isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('WhatsApp'),
                            onPressed: () => abrirWhatsapp(context, 'https://wa.me/${n['whatsapp']}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TarjetaSeguir(slug: slug, negocio: n),
                    if (fecha != null) ...[const SizedBox(height: 10), _AvisoDia(fecha: fecha!)],
                    if (tarjeta != null && tarjeta['activa'] == true) ...[
                      const SizedBox(height: 12),
                      TarjetaSellos(tarjeta: tarjeta, negocio: n['nombre'] as String?),
                    ],
                    if (cupones.isNotEmpty) ...[
                      const TituloGrupo('Tus cupones'),
                      for (final c in cupones) TarjetaCupon(cupon: c),
                    ],
                    const TituloGrupo('Elige un servicio'),
                    if (n['acepta_reservas'] != true)
                      const AvisoSuave(
                        icono: Icons.event_busy_rounded,
                        texto: 'Este lugar no está tomando reservas en línea por ahora.',
                      )
                    else
                      for (final (i, s) in servicios.indexed)
                        AparecerEnCascada(
                          indice: i,
                          child: _TarjetaServicio(
                            servicio: s,
                            alTocar: () => context.push(
                              '/cliente/negocio/$slug/reservar/${s['slug']}${fecha == null ? '' : '?fecha=$fecha'}',
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AvisoDia extends StatelessWidget {
  const _AvisoDia({required this.fecha});

  final String fecha;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: context.tonos.rosa, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Icon(Icons.event_available_rounded, color: context.tonos.acento),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Reservando para el ${Fechas.diaCorto(fecha)}. Elige el servicio.',
            style: TextStyle(color: context.tonos.acentoFuerte, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _TarjetaServicio extends StatelessWidget {
  const _TarjetaServicio({required this.servicio, required this.alTocar});

  final Json servicio;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final precio = servicio['precio_desde'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.tonos.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: context.tonos.borde),
        ),
        child: InkWell(
          key: Key('servicio-${servicio['slug']}'),
          borderRadius: BorderRadius.circular(22),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: context.tonos.rosa, borderRadius: BorderRadius.circular(15)),
                  child: Icon(Icons.auto_awesome_rounded, color: context.tonos.acento),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(servicio['nombre'] as String, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, size: 14, color: context.tonos.textoSuave),
                              const SizedBox(width: 3),
                              Text(
                                '${servicio['duracion_min']} min',
                                style: TextStyle(color: context.tonos.textoSuave, fontSize: 13),
                              ),
                            ],
                          ),
                          if (precio != null)
                            Text(
                              'desde S/ $precio',
                              style: TextStyle(color: context.tonos.acento, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(gradient: Paleta.degradado, borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                    'Reservar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reserva desde la app en pasos: (con quién) → hora → confirmar (notas y cupón). Queda «por confirmar», como en
/// la web: solo el negocio la confirma, cancela o mueve.
class ReservarClientePantalla extends ConsumerStatefulWidget {
  const ReservarClientePantalla({super.key, required this.slug, required this.motivo, this.fecha});

  final String slug;
  final String motivo;
  final String? fecha;

  @override
  ConsumerState<ReservarClientePantalla> createState() => _ReservarClienteState();
}

class _ReservarClienteState extends ConsumerState<ReservarClientePantalla> {
  final _notas = TextEditingController();
  bool _quienElegido = false;
  int? _profesional;
  String? _hora;
  int? _cupon;
  bool _enviando = false;
  Json? _hecha;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  List<Json> _profesionales(Json n) => lista(n['profesionales']).where((p) {
    final hace = p['servicios'] as List?;
    return hace == null || hace.contains(widget.motivo);
  }).toList();

  Future<void> _reservar(Json negocio) async {
    setState(() => _enviando = true);
    final notas = _notas.text.trim();
    try {
      final r = await ref.read(apiClienteProvider).post('/negocios/${widget.slug}/reservas', {
        'motivo': widget.motivo,
        'inicio': _hora,
        'profesional': ?_profesional,
        'cupon': ?_cupon,
        if (notas.isNotEmpty) 'notas': notas,
      });
      refrescarCliente(ref);
      ref.invalidate(negocioClienteProvider(widget.slug));
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _hecha = r);
      // Primera reserva en este lugar: se pregunta una sola vez por sus promociones (permiso aparte, DAT-02).
      if (r['preguntar_promos'] == true && mounted) await preguntarPromos(context, ref, widget.slug, negocio);
    } on ApiError catch (e) {
      if (!mounted) return;
      avisar(context, e.mensaje);
      // Otro tomó la hora o el número ya tiene una cita a esa hora: se vuelve a elegir.
      if (e.status == 409) setState(() => _hora = null);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _atras(bool elegir) {
    if (_hora != null) {
      setState(() => _hora = null);
    } else if (elegir && _quienElegido) {
      setState(() => _quienElegido = false);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(negocioClienteProvider(widget.slug));
    final n = datos.valueOrNull;
    final pros = n == null ? <Json>[] : _profesionales(n);
    final elegir = n != null && (n['opciones'] as Json?)?['elegir_profesional'] == true && pros.length > 1;
    final pasos = elegir ? 3 : 2;
    final paso = _hora != null ? pasos : (elegir && !_quienElegido ? 1 : pasos - 1);
    return PopScope(
      canPop: _hecha != null || (_hora == null && !(elegir && _quienElegido)),
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _atras(elegir);
      },
      child: Scaffold(
        appBar: _hecha != null
            ? null
            : AppBar(
                title: Text(n == null ? 'Reservar' : 'Reservar en ${n['nombre']}'),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: _Pasos(actual: paso, total: pasos),
                  ),
                ),
              ),
        body: datos.when(
          loading: () => const Cargando(),
          error: (e, _) =>
              ErrorConReintento(error: e, alReintentar: () => ref.invalidate(negocioClienteProvider(widget.slug))),
          data: (n) {
            final servicio = lista(n['motivos']).firstWhere((s) => s['slug'] == widget.motivo, orElse: () => {});
            final Widget cuerpo;
            if (_hecha != null) {
              cuerpo = _ReservaHecha(reserva: _hecha!, negocio: n);
            } else if (elegir && !_quienElegido) {
              cuerpo = _pasoQuien(pros);
            } else if (_hora == null) {
              cuerpo = Column(
                key: const ValueKey('hora'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${servicio['nombre'] ?? ''}: elige el día y la hora',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AvisoHoy(consulta: (slug: widget.slug, motivo: widget.motivo, profesional: _profesional)),
                  Expanded(
                    child: SelectorHora(
                      key: const Key('paso-hora'),
                      fechaPreferida: widget.fecha,
                      fuente: horasClienteProvider((
                        slug: widget.slug,
                        motivo: widget.motivo,
                        profesional: _profesional,
                      )),
                      alElegir: (h) => setState(() => _hora = h),
                    ),
                  ),
                ],
              );
            } else {
              cuerpo = _pasoConfirmar(n, servicio, pros);
            }
            return AnimatedSwitcher(
              duration: sinEfectos(context) ? Duration.zero : const Duration(milliseconds: 280),
              transitionBuilder: (hijo, animacion) => FadeTransition(
                opacity: animacion,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animacion),
                  child: hijo,
                ),
              ),
              child: cuerpo,
            );
          },
        ),
      ),
    );
  }

  Widget _pasoQuien(List<Json> pros) {
    void elegir(int? id) => setState(() {
      _profesional = id;
      _quienElegido = true;
    });
    return ListView(
      key: const Key('paso-quien'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('¿Con quién?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const Key('quien-cualquiera'),
            leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
            title: const Text('Con quien tenga la hora más cercana'),
            onTap: () => elegir(null),
          ),
        ),
        for (final p in pros)
          Card(
            child: ListTile(
              key: Key('quien-${p['id']}'),
              leading: Avatar(p['nombre'] as String),
              title: Text(p['nombre'] as String),
              subtitle: (p['detalle'] as String? ?? '').isEmpty ? null : Text(p['detalle'] as String),
              onTap: () => elegir(p['id'] as int),
            ),
          ),
      ],
    );
  }

  Widget _pasoConfirmar(Json n, Json servicio, List<Json> pros) {
    final cupones = lista(n['cupones']).where((c) => c['servicio_slug'] == null || c['servicio_slug'] == widget.motivo);
    final profesional = pros.where((p) => p['id'] == _profesional).firstOrNull;
    final textos = Theme.of(context).textTheme;
    return ListView(
      key: const Key('paso-confirmar'),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: Paleta.degradado, borderRadius: BorderRadius.circular(24)),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n['nombre'] as String, style: textos.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 10),
                Text(Fechas.diaHora(_hora!), style: textos.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text('${servicio['nombre']} · ${servicio['duracion_min']} min'),
                if (profesional != null) Text('Con ${profesional['nombre']}'),
                const SizedBox(height: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                  onPressed: () => setState(() => _hora = null),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: const Text('Cambiar la hora'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        CampoNotas(controlador: _notas, rubro: '${n['rubro'] ?? ''}', etiqueta: '¿Algo que ${n['nombre']} deba saber?'),
        if (cupones.isNotEmpty) ...[
          const TituloGrupo('¿Usas un cupón?'),
          RadioGroup<int?>(
            groupValue: _cupon,
            onChanged: (v) => setState(() => _cupon = v),
            child: Column(
              children: [
                const RadioListTile<int?>(value: null, title: Text('Sin cupón')),
                for (final c in cupones)
                  RadioListTile<int?>(
                    key: Key('usar-cupon-${c['codigo']}'),
                    value: c['id'] as int,
                    title: Text(c['titulo'] as String),
                    subtitle: Text('${c['descuento']} · código ${c['codigo']}'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${n['nombre']} confirmará tu reserva y te avisaremos aquí.',
          style: TextStyle(color: context.tonos.textoSuave),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('confirmar-reserva'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _enviando ? null : () => _reservar(n),
          child: Text(_enviando ? 'Reservando…' : 'Reservar'),
        ),
      ],
    );
  }
}

/// Barra de pasos: segmentos que se llenan.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual, required this.total});

  final int actual;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= total; i++) ...[
        if (i > 1) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 5,
            decoration: BoxDecoration(
              gradient: i <= actual ? Paleta.degradado : null,
              color: i <= actual ? null : context.tonos.rosa,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Éxito: Rubí celebra y cae confeti (una vez).
class _ReservaHecha extends StatefulWidget {
  const _ReservaHecha({required this.reserva, required this.negocio});

  final Json reserva;
  final Json negocio;

  @override
  State<_ReservaHecha> createState() => _ReservaHechaState();
}

class _ReservaHechaState extends State<_ReservaHecha> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) lanzarConfeti(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reserva = widget.reserva;
    final cupon = reserva['cupon'] as Json?;
    final textos = Theme.of(context).textTheme;
    return FondoManchas(
      child: SafeArea(
        child: ListView(
          key: const Key('reserva-hecha'),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const Center(child: Rubi(tam: 120, expresion: ExpresionRubi.celebra)),
            const SizedBox(height: 16),
            Text('¡Reserva enviada!', textAlign: TextAlign.center, style: textos.headlineMedium),
            const SizedBox(height: 14),
            Vidrio(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('${reserva['tratamiento']}', style: textos.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    Fechas.diaHora(reserva['inicio'] as String),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.tonos.acento, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: context.tonos.ambarFondo, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'Por confirmar',
                      style: TextStyle(color: context.tonos.ambarTexto, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${widget.negocio['nombre']} la confirmará y te llegará un aviso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.tonos.textoSuave),
                  ),
                  if (cupon != null) ...[
                    const SizedBox(height: 8),
                    Text('Con tu cupón ${cupon['codigo']} (${cupon['descuento']}).', textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () => context.go('/cliente/citas'),
              child: const Text('Ver mis citas'),
            ),
            TextButton(onPressed: () => context.go('/cliente'), child: const Text('Volver al inicio')),
          ],
        ),
      ),
    );
  }
}

/// Seguir al lugar y, aparte, recibir sus promociones y cupones con una notificación.
class TarjetaSeguir extends ConsumerWidget {
  const TarjetaSeguir({super.key, required this.slug, required this.negocio});

  final String slug;
  final Json negocio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siguiendo = negocio['siguiendo'] == true;
    final promos = negocio['promos'] == true;
    final tonos = context.tonos;
    return Container(
      key: const Key('tarjeta-seguir'),
      decoration: BoxDecoration(
        color: tonos.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tonos.borde),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(siguiendo ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: tonos.acento),
            title: Text(siguiendo ? 'Sigues a este lugar' : 'Seguir a este lugar'),
            subtitle: const Text('Aparece en tu inicio y te enteras de sus novedades.'),
            trailing: siguiendo
                ? TextButton(
                    onPressed: () => seguirNegocio(context, ref, slug, seguir: false),
                    child: const Text('Dejar'),
                  )
                : FilledButton(
                    key: const Key('boton-seguir'),
                    onPressed: () => seguirNegocio(context, ref, slug, seguir: true, promos: true),
                    child: const Text('Seguir'),
                  ),
          ),
          if (siguiendo)
            SwitchListTile(
              key: const Key('switch-promos'),
              value: promos,
              onChanged: (v) => seguirNegocio(context, ref, slug, seguir: true, promos: v),
              title: const Text('Recibir sus promociones y cupones'),
              subtitle: const Text('Te llegan como notificación y quedan en «Beneficios».'),
            ),
        ],
      ),
    );
  }
}

Future<void> seguirNegocio(
  BuildContext context,
  WidgetRef ref,
  String slug, {
  required bool seguir,
  bool? promos,
}) async {
  try {
    final r = await ref.read(apiClienteProvider).post('/negocios/$slug/seguir', {'seguir': seguir, 'promos': ?promos});
    ref.invalidate(negocioClienteProvider(slug));
    refrescarCliente(ref);
    if (!context.mounted) return;
    avisar(
      context,
      r['siguiendo'] != true
          ? 'Ya no sigues a este lugar.'
          : r['promos'] == true
          ? 'Listo: te avisaremos de sus promociones y cupones.'
          : 'Listo: no recibirás sus promociones.',
    );
  } on ApiError catch (e) {
    if (context.mounted) avisar(context, e.mensaje);
  }
}

/// Después de la primera reserva en un lugar: «¿Quieres recibir sus promociones?».
Future<void> preguntarPromos(BuildContext context, WidgetRef ref, String slug, Json negocio) async {
  final quiere = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('¿Quieres recibir las promociones de ${negocio['nombre']}?'),
      content: const Text(
        'Te llegarán sus descuentos y cupones con una notificación. Puedes apagarlo cuando quieras en su ficha.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('No, gracias')),
        FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Sí, quiero')),
      ],
    ),
  );
  if (quiere == null || !context.mounted) return;
  await seguirNegocio(context, ref, slug, seguir: true, promos: quiere);
}
