import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paleta.dart';
import 'vidrio.dart';
import 'tonos.dart';

class DestinoBarra {
  const DestinoBarra({required this.icono, required this.iconoActivo, required this.texto, this.insignia = 0});

  final IconData icono;
  final IconData iconoActivo;
  final String texto;

  /// Número en la burbuja (p. ej. reservas por confirmar). 0: sin burbuja.
  final int insignia;
}

/// Barra inferior flotante: una píldora blanca con sombra rosada. La pestaña activa se marca con una pastilla
/// con degradado frambuesa que se estira con resorte detrás del ícono.
class BarraFlotante extends StatelessWidget {
  const BarraFlotante({super.key, required this.indice, required this.destinos, required this.alElegir});

  final int indice;
  final List<DestinoBarra> destinos;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) {
    final sinAnimar = sinEfectos(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Vidrio(
          radio: 30,
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < destinos.length; i++)
                Expanded(
                  child: _Item(
                    destino: destinos[i],
                    activo: i == indice,
                    duracion: sinAnimar ? Duration.zero : const Duration(milliseconds: 420),
                    alTocar: () {
                      HapticFeedback.selectionClick();
                      alElegir(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.destino, required this.activo, required this.duracion, required this.alTocar});

  final DestinoBarra destino;
  final bool activo;
  final Duration duracion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final icono = Badge(
      isLabelVisible: destino.insignia > 0,
      backgroundColor: Paleta.rojo,
      label: Text('${destino.insignia}'),
      child: Icon(
        activo ? destino.iconoActivo : destino.icono,
        color: activo ? Colors.white : context.tonos.textoSuave,
      ),
    );
    return Semantics(
      selected: activo,
      button: true,
      child: InkResponse(
        onTap: alTocar,
        radius: 36,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: duracion,
                curve: Curves.easeOutCubic,
                width: activo ? 60 : 44,
                height: 34,
                decoration: BoxDecoration(
                  gradient: activo ? Paleta.degradado : null,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: activo
                      ? [
                          BoxShadow(
                            color: context.tonos.acento.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: icono),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: duracion,
                style: TextStyle(
                  fontFamily: 'Jakarta',
                  fontSize: 11.5,
                  fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                  color: activo ? context.tonos.acento : context.tonos.textoSuave,
                ),
                child: Text(destino.texto, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
