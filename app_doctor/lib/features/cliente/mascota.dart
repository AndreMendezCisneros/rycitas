import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/tonos.dart';

/// Las caras de Rubí. Pocas y claras: así se anima bien y no se vuelve infantil.
enum ExpresionRubi { contenta, pensando, celebra, dormida }

/// Rubí, la frambuesa de RyCitas: formas simples (drupas, dos hojas, ojos y mejillas). «Respira», parpadea cada
/// pocos segundos y salta con un resorte al tocarla. Aparece solo en momentos clave del modo cliente: el inicio, los
/// estados vacíos, los logros y la confirmación de una reserva.
class Rubi extends StatefulWidget {
  const Rubi({
    super.key,
    this.tam = 96,
    this.expresion = ExpresionRubi.contenta,
    this.alTocar,
    this.etiqueta = 'Rubí, toca para ver dónde reservar',
  });

  final double tam;
  final ExpresionRubi expresion;
  final VoidCallback? alTocar;
  final String etiqueta;

  @override
  State<Rubi> createState() => _RubiState();
}

class _RubiState extends State<Rubi> with TickerProviderStateMixin {
  late final AnimationController _respira = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _parpadeo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final AnimationController _salto = AnimationController.unbounded(vsync: this);
  bool _animar = true;
  Timer? _proximoParpadeo;
  int _parpadeosRestantes = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animar = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_animar) {
      _despertar();
    } else {
      _respira.stop();
      _proximoParpadeo?.cancel();
    }
  }

  /// Rubí se mueve un rato y luego se queda quieta (ahorra batería y no distrae); al tocarla, vuelve a moverse.
  void _despertar() {
    if (!_respira.isAnimating) _respira.repeat(reverse: true, count: 6);
    _parpadeosRestantes = 4;
    _programarParpadeo();
  }

  void _programarParpadeo() {
    _proximoParpadeo?.cancel();
    if (_parpadeosRestantes <= 0) return;
    _proximoParpadeo = Timer(Duration(milliseconds: 2200 + math.Random().nextInt(2400)), () async {
      if (!mounted || !_animar) return;
      _parpadeosRestantes--;
      await _parpadeo.forward();
      if (!mounted) return;
      await _parpadeo.reverse();
      if (mounted) _programarParpadeo();
    });
  }

  void _tocar() {
    HapticFeedback.lightImpact();
    if (_animar) {
      // Resorte «Expressive»: sube rápido y rebota un poco al caer.
      _salto.animateWith(SpringSimulation(const SpringDescription(mass: 1, stiffness: 380, damping: 11), 0, 0, -2.6));
      _despertar();
    }
    widget.alTocar?.call();
  }

  @override
  void dispose() {
    _proximoParpadeo?.cancel();
    _respira.dispose();
    _parpadeo.dispose();
    _salto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capa propia: su animación no obliga a repintar la pantalla de alrededor.
    return RepaintBoundary(
      child: Semantics(
        button: widget.alTocar != null,
        label: widget.etiqueta,
        child: GestureDetector(
          key: const Key('rubi'),
          onTap: widget.alTocar == null ? null : _tocar,
          child: AnimatedBuilder(
            animation: Listenable.merge([_respira, _parpadeo, _salto]),
            builder: (_, _) {
              final respiro = Curves.easeInOut.transform(_respira.value);
              final salto = _salto.value.clamp(-1.0, 1.0);
              return Transform.translate(
                offset: Offset(0, salto * widget.tam * 0.18),
                child: Transform.scale(
                  scaleX: 1 + 0.015 * respiro - salto * 0.04,
                  scaleY: 1 - 0.025 * respiro + salto * 0.06,
                  alignment: Alignment.bottomCenter,
                  child: CustomPaint(
                    size: Size.square(widget.tam),
                    painter: _PintorRubi(
                      expresion: widget.expresion,
                      ojosCerrados: widget.expresion == ExpresionRubi.dormida ? 1 : _parpadeo.value,
                      brillo: respiro,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PintorRubi extends CustomPainter {
  _PintorRubi({required this.expresion, required this.ojosCerrados, required this.brillo});

  final ExpresionRubi expresion;
  final double ojosCerrados;
  final double brillo;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centro = Offset(w / 2, h * 0.58);

    // Sombra en el piso.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.97), width: w * 0.5, height: h * 0.06),
      Paint()..color = Paleta.frambuesaOscura.withValues(alpha: 0.12),
    );

    // Cuerpo: una gota redondeada.
    final cuerpo = Path()
      ..moveTo(w * 0.5, h * 0.22)
      ..cubicTo(w * 0.86, h * 0.20, w * 0.95, h * 0.55, w * 0.80, h * 0.78)
      ..cubicTo(w * 0.70, h * 0.93, w * 0.30, h * 0.93, w * 0.20, h * 0.78)
      ..cubicTo(w * 0.05, h * 0.55, w * 0.14, h * 0.20, w * 0.5, h * 0.22)
      ..close();
    canvas.drawPath(
      cuerpo,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [Paleta.coral, Paleta.rojo, Paleta.frambuesa],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromLTWH(0, h * 0.2, w, h * 0.75)),
    );

    // Drupas: círculos con un brillo pequeño. Fila por fila, recortadas al cuerpo.
    canvas.save();
    canvas.clipPath(cuerpo);
    final r = w * 0.085;
    final drupa = Paint()..color = Paleta.frambuesaOscura.withValues(alpha: 0.18);
    final luz = Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.1 * brillo);
    for (var fila = 0; fila < 6; fila++) {
      final y = h * 0.28 + fila * r * 1.55;
      final desfase = fila.isOdd ? r : 0.0;
      for (var x = w * 0.12 + desfase; x < w * 0.92; x += r * 2) {
        canvas.drawCircle(Offset(x, y), r * 0.92, Paint()..color = Paleta.frambuesa.withValues(alpha: 0.10));
        canvas.drawCircle(
          Offset(x + r * 0.15, y + r * 0.2),
          r * 0.85,
          drupa
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.drawCircle(Offset(x - r * 0.3, y - r * 0.3), r * 0.18, luz);
      }
    }
    canvas.restore();

    // Hojas.
    final hoja = Paint()..color = const Color(0xFF3FA66B);
    final hojaOscura = Paint()..color = const Color(0xFF2E8556);
    Path hojaEn(double angulo) {
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(w * 0.10, -h * 0.10, w * 0.22, -h * 0.02)
        ..quadraticBezierTo(w * 0.10, h * 0.04, 0, 0);
      return p.transform(
        (Matrix4.identity()
              ..translateByDouble(w * 0.5, h * 0.22, 0, 1)
              ..rotateZ(angulo))
            .storage,
      );
    }

    canvas.drawPath(hojaEn(-math.pi * 0.95), hojaOscura);
    canvas.drawPath(hojaEn(-math.pi * 0.05), hoja);
    canvas.drawPath(hojaEn(-math.pi * 0.5), hoja);
    canvas.drawCircle(Offset(w * 0.5, h * 0.21), w * 0.03, hojaOscura);

    // Cara.
    final ojoY = centro.dy - h * 0.02;
    final sep = w * 0.15;
    final tinta = Paint()..color = const Color(0xFF2A1A22);
    final blanco = Paint()..color = Colors.white;
    for (final lado in [-1.0, 1.0]) {
      final ojo = Offset(centro.dx + lado * sep, ojoY);
      final cerrado = expresion == ExpresionRubi.celebra ? 1.0 : ojosCerrados;
      if (cerrado > 0.6) {
        // Ojo cerrado: una curva (feliz al celebrar, recta al dormir).
        final arco = Path()
          ..moveTo(ojo.dx - w * 0.05, ojo.dy)
          ..quadraticBezierTo(
            ojo.dx,
            ojo.dy + (expresion == ExpresionRubi.dormida ? h * 0.012 : -h * 0.05),
            ojo.dx + w * 0.05,
            ojo.dy,
          );
        canvas.drawPath(
          arco,
          Paint()
            ..color = tinta.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.025
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final alto = h * 0.11 * (1 - cerrado);
        canvas.drawOval(Rect.fromCenter(center: ojo, width: w * 0.105, height: alto), blanco);
        final mira = expresion == ExpresionRubi.pensando ? Offset(w * 0.018, -h * 0.022) : Offset(0, h * 0.008);
        canvas.drawOval(Rect.fromCenter(center: ojo + mira, width: w * 0.06, height: alto * 0.62), tinta);
        canvas.drawCircle(ojo + mira + Offset(-w * 0.012, -alto * 0.15), w * 0.012, blanco);
      }
      // Mejilla.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ojo.dx + lado * w * 0.06, ojoY + h * 0.085), width: w * 0.1, height: h * 0.05),
        Paint()..color = const Color(0xFFFF9FB2).withValues(alpha: 0.75),
      );
    }

    // Boca.
    final boca = Offset(centro.dx, ojoY + h * 0.09);
    final trazo = Paint()
      ..color = tinta.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    switch (expresion) {
      case ExpresionRubi.celebra:
        final abierta = Path()
          ..moveTo(boca.dx - w * 0.07, boca.dy - h * 0.01)
          ..quadraticBezierTo(boca.dx, boca.dy + h * 0.09, boca.dx + w * 0.07, boca.dy - h * 0.01)
          ..close();
        canvas.drawPath(abierta, tinta);
        canvas.drawCircle(Offset(boca.dx, boca.dy + h * 0.035), w * 0.025, Paint()..color = const Color(0xFFFF7A85));
      case ExpresionRubi.pensando:
        canvas.drawLine(Offset(boca.dx - w * 0.03, boca.dy + h * 0.01), Offset(boca.dx + w * 0.04, boca.dy), trazo);
      case ExpresionRubi.dormida:
        canvas.drawOval(Rect.fromCenter(center: boca, width: w * 0.04, height: h * 0.03), trazo);
      case ExpresionRubi.contenta:
        final sonrisa = Path()
          ..moveTo(boca.dx - w * 0.06, boca.dy - h * 0.005)
          ..quadraticBezierTo(boca.dx, boca.dy + h * 0.05, boca.dx + w * 0.06, boca.dy - h * 0.005);
        canvas.drawPath(sonrisa, trazo);
    }

    // Brillos al celebrar.
    if (expresion == ExpresionRubi.celebra) {
      final chispa = Paint()..color = const Color(0xFFFFC94D);
      for (final (dx, dy, t) in [(0.1, 0.2, 0.05), (0.9, 0.3, 0.04), (0.85, 0.08, 0.03)]) {
        _estrella(canvas, Offset(w * dx, h * dy), w * t * (0.8 + 0.4 * brillo), chispa);
      }
    }
    if (expresion == ExpresionRubi.dormida) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(color: Paleta.frambuesa, fontSize: w * 0.16, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.8, h * (0.12 - 0.04 * brillo)));
    }
  }

  void _estrella(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final ang = i * math.pi / 4;
      final radio = i.isEven ? r : r * 0.35;
      final punto = c + Offset(math.cos(ang) * radio, math.sin(ang) * radio);
      i == 0 ? path.moveTo(punto.dx, punto.dy) : path.lineTo(punto.dx, punto.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(_PintorRubi viejo) =>
      viejo.expresion != expresion || viejo.ojosCerrados != ojosCerrados || viejo.brillo != brillo;
}

/// Globo de diálogo de Rubí.
class GloboRubi extends StatelessWidget {
  const GloboRubi({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: context.tonos.superficie,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(18),
        bottomLeft: Radius.circular(4),
      ),
      boxShadow: Paleta.sombra(0.7),
    ),
    child: Text(
      texto,
      style: TextStyle(color: context.tonos.texto, fontWeight: FontWeight.w700, height: 1.3),
    ),
  );
}

/// Saludo según la hora, en tono cálido de adulto.
String saludoRubi(String nombre, DateTime ahora) {
  final primero = nombre.trim().split(RegExp(r'\s+')).first;
  final h = ahora.hour;
  final saludo = h < 12
      ? 'Buenos días'
      : h < 19
      ? 'Buenas tardes'
      : 'Buenas noches';
  final frases = ['¿Te consentimos hoy?', '¿Reservamos algo para ti?', 'Tus lugares favoritos te esperan.'];
  return '$saludo, $primero. ${frases[ahora.day % frases.length]}';
}
