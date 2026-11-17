import 'package:flutter/material.dart';

import 'paleta.dart';
import 'tonos.dart';

/// ¿Hay que ahorrar efectos? Alto contraste o «quitar animaciones» del sistema: superficies sólidas y sin movimiento.
bool sinEfectos(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  return mq != null && (mq.highContrast || mq.disableAnimations);
}

/// Superficie flotante translúcida. Sin desenfoque en vivo (BackdropFilter): en teléfonos de gama media se
/// recalculaba en cada fotograma y hacía sentir la app lenta. El color casi opaco ([Tonos.vidrio]) deja ver apenas el
/// fondo y el texto siempre se lee.
class Vidrio extends StatelessWidget {
  const Vidrio({super.key, required this.child, this.radio = 28, this.padding, this.sombra = true});

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry? padding;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final t = context.tonos;
    final solido = sinEfectos(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        color: solido ? t.superficie : t.vidrio,
        border: Border.all(color: t.borde),
        boxShadow: sombra ? Paleta.sombra(context.oscuro ? 0.5 : 1) : null,
      ),
      child: child,
    );
  }
}

/// Fondo con «manchas» de color difuminadas. Se pinta una sola vez (RepaintBoundary): no cuesta al hacer scroll.
class FondoManchas extends StatelessWidget {
  const FondoManchas({super.key, required this.child, this.intensidad = 1});

  final Widget child;
  final double intensidad;

  @override
  Widget build(BuildContext context) {
    final t = context.tonos;
    final fuerza = intensidad * t.manchas;
    Widget mancha(Color color, double tam) => Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.30 * fuerza),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: t.fondo)),
                Positioned(top: -120, right: -100, child: mancha(Paleta.coral, 340)),
                Positioned(top: 80, left: -140, child: mancha(Paleta.frambuesa, 300)),
                Positioned(bottom: -160, right: -80, child: mancha(context.oscuro ? Paleta.frambuesa : t.rosa, 360)),
              ],
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Abre una hoja flotante (los detalles de un día, de una cita, la reserva rápida…). Debajo se oscurece la pantalla,
/// así queda claro que es una capa encima.
Future<T?> mostrarHojaVidrio<T>(BuildContext context, {required WidgetBuilder builder, bool altoCompleto = false}) {
  final t = context.tonos;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Encima de todo, también de la barra de navegación: es una capa aparte.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: context.oscuro ? 0.55 : 0.32),
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + MediaQuery.viewInsetsOf(contexto).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: t.superficie,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: t.borde),
          boxShadow: Paleta.sombra(),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(contexto).height * (altoCompleto ? 0.92 : 0.8)),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: t.borde, borderRadius: BorderRadius.circular(3)),
                ),
                Flexible(child: builder(contexto)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Cabecera con degradado frambuesa→rojo y esquinas inferiores redondeadas. Su texto va en blanco.
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
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: child,
        ),
      ),
    ),
  );
}
