import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'paleta.dart';
import 'vidrio.dart';
import 'tonos.dart';

/// Anillo de progreso que se llena animado (nivel, tarjeta de sellos).
class AnilloProgreso extends StatelessWidget {
  const AnilloProgreso({super.key, required this.valor, this.tam = 72, this.centro, this.grosor = 7});

  final double valor;
  final double tam;
  final Widget? centro;
  final double grosor;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: valor.clamp(0, 1)),
    duration: sinEfectos(context) ? Duration.zero : const Duration(milliseconds: 1100),
    curve: Curves.easeOutCubic,
    builder: (_, v, hijo) => CustomPaint(
      size: Size.square(tam),
      painter: _PintorAnillo(v, grosor, context.tonos.rosa),
      child: SizedBox.square(
        dimension: tam,
        child: Center(child: hijo),
      ),
    ),
    child: centro,
  );
}

class _PintorAnillo extends CustomPainter {
  _PintorAnillo(this.valor, this.grosor, this.pista);

  final double valor;
  final double grosor;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final zona = rect.deflate(grosor / 2);
    canvas.drawArc(
      zona,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = pista
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );
    if (valor <= 0) return;
    canvas.drawArc(
      zona,
      -math.pi / 2,
      math.pi * 2 * valor,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: const [Paleta.frambuesa, Paleta.rojo, Paleta.coral, Paleta.frambuesa],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = grosor,
    );
  }

  @override
  bool shouldRepaint(_PintorAnillo viejo) => viejo.valor != valor || viejo.pista != pista;
}
