import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

const claveTema = 'tema_app';

/// Claro, oscuro o el del teléfono (por defecto). Se guarda en el teléfono.
class Apariencia extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(_restaurar);
    return ThemeMode.system;
  }

  static ThemeMode _de(String? valor) => switch (valor) {
    'claro' => ThemeMode.light,
    'oscuro' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> _restaurar() async {
    final guardado = _de(await ref.read(almacenProvider).leer(claveTema));
    if (guardado != state) state = guardado;
  }

  Future<void> elegir(ThemeMode modo) async {
    state = modo;
    await ref.read(almacenProvider).escribir(claveTema, switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'oscuro',
      ThemeMode.system => 'sistema',
    });
  }
}

final aparienciaProvider = NotifierProvider<Apariencia, ThemeMode>(Apariencia.new);

/// Selector «Tema» para Ajustes (negocio) y Perfil (cliente).
class SelectorTema extends ConsumerWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(aparienciaProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const Key('selector-tema'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Oscuro')),
              ],
              selected: {modo},
              onSelectionChanged: (s) => ref.read(aparienciaProvider.notifier).elegir(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
