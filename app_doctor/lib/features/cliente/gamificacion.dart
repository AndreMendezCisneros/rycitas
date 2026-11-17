import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/diseno/anillo.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import 'datos_cliente.dart';
import 'mascota.dart';

IconData _icono(String clave) => switch (clave) {
  'estrella' => Icons.star_rounded,
  'corazon' => Icons.favorite_rounded,
  'reloj' => Icons.schedule_rounded,
  'brujula' => Icons.explore_rounded,
  'regalo' => Icons.card_giftcard_rounded,
  'fuego' => Icons.local_fire_department_rounded,
  _ => Icons.emoji_events_rounded,
};

/// Progreso del cliente en el inicio: nivel con su barra, racha y puntos. Siempre dice cuánto falta (sin culpas).
class TarjetaProgreso extends ConsumerWidget {
  const TarjetaProgreso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(logrosProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final nivel = d['nivel'] as Json;
    final racha = d['racha'] as int? ?? 0;
    final textos = Theme.of(context).textTheme;
    final siguiente = nivel['siguiente'] as String?;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('tarjeta-progreso'),
        borderRadius: BorderRadius.circular(26),
        onTap: () => context.go('/cliente/beneficios'),
        child: Vidrio(
          radio: 26,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnilloProgreso(
                valor: (nivel['progreso'] as num).toDouble(),
                tam: 64,
                centro: const Icon(Icons.workspace_premium_rounded, color: Paleta.frambuesa, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nivel ${nivel['nombre']}', style: textos.titleMedium),
                    Text(
                      siguiente == null
                          ? '¡Llegaste al nivel más alto!'
                          : 'Te faltan ${nivel['faltan']} visita${nivel['faltan'] == 1 ? '' : 's'} para $siguiente',
                      style: textos.bodySmall?.copyWith(color: Paleta.textoSuave),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pildora(
                          icono: Icons.local_fire_department_rounded,
                          texto: racha == 0
                              ? 'Sin racha aún'
                              : '$racha mes${racha == 1 ? '' : 'es'}${d['racha_activa'] == true ? '' : ' · en pausa'}',
                          color: const Color(0xFFF97316),
                        ),
                        _Pildora(
                          icono: Icons.auto_awesome_rounded,
                          texto: '${d['puntos']} puntos',
                          color: Paleta.frambuesa,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Paleta.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora({required this.icono, required this.texto, required this.color});

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}

/// Insignias en «Beneficios»: grises si faltan, con brillo si se lograron. Al tocar, cómo conseguirla.
class SeccionLogros extends ConsumerWidget {
  const SeccionLogros({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(logrosProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final logros = lista(d['logros']);
    final hechos = logros.where((l) => l['logrado'] == true).length;
    return Column(
      key: const Key('seccion-logros'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Tus logros', style: Theme.of(context).textTheme.titleMedium)),
            Text(
              '$hechos de ${logros.length}',
              style: const TextStyle(color: Paleta.textoSuave, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [for (final l in logros) _Insignia(logro: l)],
        ),
      ],
    );
  }
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.logro});

  final Json logro;

  @override
  Widget build(BuildContext context) {
    final hecho = logro['logrado'] == true;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: hecho ? Paleta.rosa : Paleta.borde),
      ),
      child: InkWell(
        key: Key('logro-${logro['clave']}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => _detalle(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hecho ? Paleta.degradado : null,
                  color: hecho ? null : const Color(0xFFF1ECEE),
                  boxShadow: hecho
                      ? [BoxShadow(color: Paleta.rojo.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 1)]
                      : null,
                ),
                child: Icon(
                  hecho ? _icono(logro['icono'] as String) : Icons.lock_rounded,
                  color: hecho ? Colors.white : Paleta.gris,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                logro['titulo'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hecho ? Paleta.texto : Paleta.textoSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _detalle(BuildContext context) {
    final hecho = logro['logrado'] == true;
    final progreso = logro['progreso'] as int;
    final meta = logro['meta'] as int;
    if (hecho) lanzarConfeti(context);
    mostrarHojaVidrio<void>(
      context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Rubi(tam: 80, expresion: hecho ? ExpresionRubi.celebra : ExpresionRubi.pensando),
            const SizedBox(height: 10),
            Text(logro['titulo'] as String, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              hecho ? '¡Lo lograste! 🎉' : logro['como'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Paleta.textoSuave),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso / meta,
                minHeight: 10,
                color: Paleta.frambuesa,
                backgroundColor: Paleta.rosa,
              ),
            ),
            const SizedBox(height: 6),
            Text('$progreso de $meta', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Confeti breve (menos de 1,5 s) encima de todo: al llenar una tarjeta, confirmar una reserva o ver un logro.
void lanzarConfeti(BuildContext context) {
  if (sinEfectos(context)) return;
  final capa = Overlay.maybeOf(context, rootOverlay: true);
  if (capa == null) return;
  HapticFeedback.mediumImpact();
  late final OverlayEntry entrada;
  entrada = OverlayEntry(builder: (_) => _Confeti(alTerminar: () => entrada.remove()));
  capa.insert(entrada);
}

class _Confeti extends StatefulWidget {
  const _Confeti({required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<_Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<_Confeti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward().whenComplete(widget.alTerminar);
  final _piezas = List.generate(60, (i) {
    final r = math.Random(i * 7919);
    return (
      x: r.nextDouble(),
      vx: (r.nextDouble() - 0.5) * 0.6,
      vy: 0.6 + r.nextDouble() * 0.9,
      giro: r.nextDouble() * math.pi * 2,
      color: [Paleta.frambuesa, Paleta.rojo, Paleta.coral, const Color(0xFFFFC94D), Paleta.rosa][i % 5],
      tam: 6.0 + r.nextDouble() * 6,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(size: MediaQuery.sizeOf(context), painter: _PintorConfeti(_c.value, _piezas)),
    ),
  );
}

class _PintorConfeti extends CustomPainter {
  _PintorConfeti(this.t, this.piezas);

  final double t;
  final List<({double x, double vx, double vy, double giro, Color color, double tam})> piezas;

  @override
  void paint(Canvas canvas, Size size) {
    final opacidad = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    for (final p in piezas) {
      final x = size.width * (p.x + p.vx * t);
      final y = -20 + size.height * p.vy * t + 300 * t * t;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.giro + t * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.tam, height: p.tam * 0.55),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withValues(alpha: opacidad.clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorConfeti viejo) => viejo.t != t;
}
