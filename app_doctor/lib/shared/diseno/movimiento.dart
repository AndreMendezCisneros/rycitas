import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tonos.dart';

const duracionCorta = Duration(milliseconds: 220);
const duracionMedia = Duration(milliseconds: 300);
const curvaEntrada = Curves.easeOutCubic;

bool _sinAnimaciones(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Página de go_router con «fade through» (Material): para pasar entre pantallas que no comparten contenido.
Page<void> paginaConTransicion(GoRouterState estado, Widget hijo) => CustomTransitionPage<void>(
  key: estado.pageKey,
  child: hijo,
  transitionDuration: duracionMedia,
  reverseTransitionDuration: duracionCorta,
  transitionsBuilder: (context, animacion, secundaria, child) => _sinAnimaciones(context)
      ? child
      : FadeThroughTransition(
          animation: animacion,
          secondaryAnimation: secundaria,
          fillColor: Colors.transparent,
          child: child,
        ),
);

/// Contenedor de las pestañas (StatefulShellRoute): la pestaña nueva entra deslizándose desde el lado hacia el que
/// se tocó y la anterior se desvanece («eje compartido» horizontal). Todas siguen vivas: no se pierde el scroll.
class PestanasAnimadas extends StatefulWidget {
  const PestanasAnimadas({super.key, required this.indice, required this.hijos});

  final int indice;
  final List<Widget> hijos;

  @override
  State<PestanasAnimadas> createState() => _PestanasAnimadasState();
}

class _PestanasAnimadasState extends State<PestanasAnimadas> {
  late int _anterior = widget.indice;

  @override
  void didUpdateWidget(PestanasAnimadas viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.indice != widget.indice) _anterior = viejo.indice;
  }

  @override
  Widget build(BuildContext context) {
    final sinAnimar = _sinAnimaciones(context);
    final haciaLaDerecha = widget.indice >= _anterior;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.hijos.length; i++)
          _Pestana(
            key: ValueKey(i),
            activa: i == widget.indice,
            visible: i == widget.indice || i == _anterior,
            desplazamiento: i == widget.indice
                ? 0
                : (i < widget.indice) == haciaLaDerecha
                ? -0.06
                : 0.06,
            duracion: sinAnimar ? Duration.zero : duracionMedia,
            // Terminó de salir: se oculta del todo (ni se pinta ni lo leen los lectores de pantalla).
            alTerminar: i == _anterior && i != widget.indice ? () => setState(() => _anterior = widget.indice) : null,
            child: widget.hijos[i],
          ),
      ],
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    super.key,
    required this.activa,
    required this.visible,
    required this.desplazamiento,
    required this.duracion,
    required this.child,
    this.alTerminar,
  });

  final VoidCallback? alTerminar;
  final bool activa;
  final bool visible;
  final double desplazamiento;
  final Duration duracion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !activa,
      child: TickerMode(
        // La que sale necesita su ticker para desvanecerse; las demás quedan quietas.
        enabled: visible,
        child: AnimatedSlide(
          offset: Offset(activa ? 0 : desplazamiento, 0),
          duration: duracion,
          curve: curvaEntrada,
          child: AnimatedOpacity(
            opacity: activa ? 1 : 0,
            duration: duracion,
            curve: curvaEntrada,
            onEnd: alTerminar,
            // Las pestañas que no están ni entrando ni saliendo no se pintan.
            child: Offstage(offstage: !visible && !activa, child: child),
          ),
        ),
      ),
    );
  }
}

/// Los elementos de una lista entran escalonados (suben 16 px y aparecen). [indice] marca el retraso.
class AparecerEnCascada extends StatefulWidget {
  const AparecerEnCascada({super.key, required this.indice, required this.child});

  final int indice;
  final Widget child;

  @override
  State<AparecerEnCascada> createState() => _AparecerEnCascadaState();
}

class _AparecerEnCascadaState extends State<AparecerEnCascada> with SingleTickerProviderStateMixin {
  late final _control = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _curva = CurvedAnimation(parent: _control, curve: curvaEntrada);

  @override
  void initState() {
    super.initState();
    final retraso = Duration(milliseconds: 40 * widget.indice.clamp(0, 10));
    Future.delayed(retraso, () {
      if (mounted) _control.forward();
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sinAnimaciones(context)) return widget.child;
    return FadeTransition(
      opacity: _curva,
      child: AnimatedBuilder(
        animation: _curva,
        builder: (_, hijo) => Transform.translate(offset: Offset(0, 16 * (1 - _curva.value)), child: hijo),
        child: widget.child,
      ),
    );
  }
}

/// Tarjeta que «crece» hasta convertirse en su pantalla de detalle (container transform).
class TarjetaQueSeAbre extends StatelessWidget {
  const TarjetaQueSeAbre({super.key, required this.cerrada, required this.abierta, this.radio = 24});

  final Widget Function(BuildContext context, VoidCallback abrir) cerrada;
  final WidgetBuilder abierta;
  final double radio;

  @override
  Widget build(BuildContext context) => OpenContainer<void>(
    transitionDuration: _sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 380),
    closedElevation: 0,
    openElevation: 0,
    closedColor: context.tonos.superficie,
    middleColor: context.tonos.superficieSuave,
    closedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radio),
      side: BorderSide(color: context.tonos.borde),
    ),
    closedBuilder: cerrada,
    openBuilder: (contexto, _) => abierta(contexto),
  );
}

/// Un número que «cuenta» hasta su valor (métricas, sellos, puntos).
class NumeroAnimado extends StatelessWidget {
  const NumeroAnimado({super.key, required this.valor, this.estilo, this.sufijo = ''});

  final num valor;
  final TextStyle? estilo;
  final String sufijo;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: valor.toDouble()),
    duration: _sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 900),
    curve: curvaEntrada,
    builder: (_, v, _) => Text('${v.round()}$sufijo', style: estilo),
  );
}
