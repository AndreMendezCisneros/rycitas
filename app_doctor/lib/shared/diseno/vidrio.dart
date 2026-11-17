import 'dart:ui';

import 'package:flutter/material.dart';

import 'paleta.dart';

/// ¿Hay que ahorrar efectos? Alto contraste o «quitar animaciones» del sistema: superficies sólidas y sin movimiento.
bool sinEfectos(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  return mq != null && (mq.highContrast || mq.disableAnimations);
}

/// Superficie translúcida («vidrio esmerilado»). Solo para cosas que flotan (hojas, barra, tarjeta destacada):
/// blanco al 85 % para que el texto se lea siempre, y blur moderado (sigma 14) porque el blur cuesta en
/// teléfonos económicos. Con alto contraste o sin animaciones, es una superficie sólida.
class Vidrio extends StatelessWidget {
  const Vidrio({
    super.key,
    required this.child,
    this.radio = 28,
    this.opacidad = 0.85,
    this.desenfoque = 14,
    this.padding,
    this.sombra = true,
  });

  final Widget child;
  final double radio;
  final double opacidad;
  final double desenfoque;
  final EdgeInsetsGeometry? padding;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final solido = sinEfectos(context);
    final borde = BorderRadius.circular(radio);
    final contenido = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borde,
        color: Colors.white.withValues(alpha: solido ? 1 : opacidad),
        border: Border.all(color: solido ? Paleta.borde : Colors.white.withValues(alpha: 0.7)),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borde, boxShadow: sombra ? Paleta.sombra() : null),
      child: ClipRRect(
        borderRadius: borde,
        child: solido || desenfoque <= 0
            ? contenido
            : BackdropFilter(filter: ImageFilter.blur(sigmaX: desenfoque, sigmaY: desenfoque), child: contenido),
      ),
    );
  }
}

/// Fondo con «manchas» de color difuminadas: le da al vidrio algo que dejar ver. Sobre blanco liso no se notaría.
class FondoManchas extends StatelessWidget {
  const FondoManchas({super.key, required this.child, this.intensidad = 1});

  final Widget child;
  final double intensidad;

  @override
  Widget build(BuildContext context) {
    Widget mancha(Color color, double tam) => Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.30 * intensidad), color.withValues(alpha: 0)],
        ),
      ),
    );
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Paleta.fondo)),
        Positioned(top: -120, right: -100, child: mancha(Paleta.coral, 340)),
        Positioned(top: 80, left: -140, child: mancha(Paleta.frambuesa, 300)),
        Positioned(bottom: -160, right: -80, child: mancha(Paleta.rosa, 360)),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Abre una hoja flotante de vidrio (los detalles de un día, de una cita, la reserva rápida…). Debajo se desenfoca
/// la pantalla, así queda claro que es una capa encima.
Future<T?> mostrarHojaVidrio<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool altoCompleto = false,
}) {
  final solido = sinEfectos(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Encima de todo, también de la barra de navegación: es una capa aparte.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    barrierColor: Paleta.texto.withValues(alpha: 0.25),
    builder: (contexto) {
      final hoja = Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + MediaQuery.viewInsetsOf(contexto).bottom),
        child: Vidrio(
          radio: 32,
          opacidad: 0.92,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * (altoCompleto ? 0.92 : 0.8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Paleta.borde, borderRadius: BorderRadius.circular(3)),
                ),
                Flexible(child: builder(contexto)),
              ],
            ),
          ),
        ),
      );
      if (solido) return hoja;
      return BackdropFilter(filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: hoja);
    },
  );
}

/// Cabecera con degradado frambuesa→rojo y esquinas inferiores redondeadas.
class CabeceraDegradado extends StatelessWidget {
  const CabeceraDegradado({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: Paleta.degradado,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
      ),
    ),
  );
}
