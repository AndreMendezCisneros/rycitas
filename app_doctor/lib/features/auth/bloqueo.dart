import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/api.dart';
import 'sesion.dart';

/// Huella, rostro o el PIN del propio teléfono. Es una interfaz para poder probar sin un dispositivo.
abstract class Autenticador {
  Future<bool> disponible();
  Future<bool> autenticar(String motivo);
}

class AutenticadorLocal implements Autenticador {
  const AutenticadorLocal();
  static final _auth = LocalAuthentication();

  @override
  Future<bool> disponible() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> autenticar(String motivo) async {
    try {
      // biometricOnly: false → si no hay huella, el patrón o el PIN del equipo.
      return await _auth.authenticate(localizedReason: motivo, persistAcrossBackgrounding: true);
    } on Exception {
      return false;
    }
  }
}

final autenticadorProvider = Provider<Autenticador>((ref) => const AutenticadorLocal());

const claveBloqueoActivo = 'bloqueo_activo';

/// Mejora 7 del análisis: la agenda tiene nombres y celulares. Si el teléfono queda prestado o se pierde, pide
/// la huella o el PIN al abrir la app y al volver después de [espera].
class Bloqueo extends Notifier<bool> {
  static const espera = Duration(minutes: 5);

  bool activo = false;
  DateTime? _salio;
  AppLifecycleListener? _ciclo;

  @override
  bool build() {
    final sesion = ref.watch(sesionProvider);
    ref.onDispose(() => _ciclo?.dispose());
    if (sesion != EstadoSesion.activa) return false;
    Future.microtask(_cargar);
    _ciclo = AppLifecycleListener(
      onHide: () => _salio = DateTime.now(),
      onShow: () {
        final salio = _salio;
        if (activo && salio != null && DateTime.now().difference(salio) >= espera) state = true;
        _salio = null;
      },
    );
    return false;
  }

  Future<void> _cargar() async {
    activo = await ref.read(almacenProvider).leer(claveBloqueoActivo) == '1';
    if (activo) state = true; // al abrir la app
  }

  Future<bool> desbloquear() async {
    final ok = await ref.read(autenticadorProvider).autenticar('Desbloquea para ver tu agenda');
    if (ok) state = false;
    return ok;
  }

  /// Devuelve un mensaje si no se pudo activar.
  Future<String?> cambiar(bool encender) async {
    final autenticador = ref.read(autenticadorProvider);
    if (encender) {
      if (!await autenticador.disponible()) return 'Este teléfono no tiene huella ni bloqueo de pantalla.';
      if (!await autenticador.autenticar('Confirma para activar el bloqueo')) return 'No se activó el bloqueo.';
      await ref.read(almacenProvider).escribir(claveBloqueoActivo, '1');
    } else {
      await ref.read(almacenProvider).borrar(claveBloqueoActivo);
    }
    activo = encender;
    ref.notifyListeners();
    return null;
  }
}

final bloqueoProvider = NotifierProvider<Bloqueo, bool>(Bloqueo.new);

/// Tapa toda la app mientras está bloqueada.
class CapaBloqueo extends ConsumerWidget {
  const CapaBloqueo({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloqueada = ref.watch(bloqueoProvider);
    if (!bloqueada) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            key: const Key('capa-bloqueo'),
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Agenda bloqueada',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Usa tu huella o el PIN del teléfono.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => ref.read(bloqueoProvider.notifier).desbloquear(),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
