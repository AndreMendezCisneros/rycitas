import 'package:flutter/material.dart';

import '../../shared/diseno/tonos.dart';
import '../../shared/diseno/vidrio.dart';

/// «¿Cómo funciona?»: sellos, cupones, racha y nivel, en palabras simples y con un ejemplo cada uno.
Future<void> mostrarComoFunciona(BuildContext context) =>
    mostrarHojaVidrio<void>(context, altoCompleto: true, builder: (_) => const ComoFunciona());

class ComoFunciona extends StatelessWidget {
  const ComoFunciona({super.key});

  static const _partes = [
    (
      Icons.loyalty_rounded,
      'Tarjeta de sellos',
      'Cada lugar tiene su propia tarjeta. Ganas 1 sello cada vez que te atienden, y 1 más si llegas a tiempo.',
      'Ejemplo: la tarjeta es de 6 sellos. Al llenarla ganas el premio (por ejemplo, un corte gratis). Muéstralo en '
          'el local y ellos lo entregan; la tarjeta vuelve a empezar.',
    ),
    (
      Icons.local_offer_rounded,
      'Cupones',
      'Los lugares que sigues te los mandan con una notificación y quedan guardados en «Beneficios».',
      'Cómo se usan: al reservar desde la app, en el último paso eliges el cupón. El lugar lo ve en tu cita y te '
          'descuenta al cobrar. Cada cupón sirve una vez; si cancelas la cita, vuelve a quedar libre.',
    ),
    (
      Icons.local_fire_department_rounded,
      'Racha',
      'Son los meses seguidos en que fuiste a algún lugar (cualquiera).',
      'Ejemplo: fuiste en septiembre, octubre y noviembre, así que tienes una racha de 3 meses. Si pasa un mes sin '
          'visita, la racha queda «en pausa»: no se borra.',
    ),
    (
      Icons.workspace_premium_rounded,
      'Nivel y logros',
      'Suben con tus visitas terminadas: Nueva, Habitual (3), Fiel (8), VIP (15) y Leyenda (30).',
      'Son medallas para ver tu avance, no se cambian por dinero. Los premios de verdad son los sellos y los cupones.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final tonos = context.tonos;
    return ListView(
      key: const Key('como-funciona'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text('¿Cómo funciona?', style: textos.titleLarge)),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final (icono, titulo, que, ejemplo) in _partes)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tonos.superficie,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tonos.borde),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: tonos.rosa, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, color: tonos.acento, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: textos.titleMedium),
                      const SizedBox(height: 2),
                      Text(que, style: textos.bodyMedium),
                      const SizedBox(height: 6),
                      Text(ejemplo, style: textos.bodySmall?.copyWith(color: tonos.textoSuave)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
