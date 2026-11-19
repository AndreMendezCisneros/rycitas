import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/tonos.dart';

/// Solo los 9 dígitos del celular peruano, o null si todavía no está completo.
String? celularCompleto(String texto) {
  final digitos = texto.replaceAll(RegExp(r'\D'), '');
  final nueve = digitos.length == 11 && digitos.startsWith('51') ? digitos.substring(2) : digitos;
  return RegExp(r'^9\d{8}$').hasMatch(nueve) ? nueve : null;
}

/// ¿Ese número tiene la app de cliente? Devuelve su nombre (nunca el correo).
final cuentaAppProvider = FutureProvider.autoDispose.family<String?, String>((ref, celular) async {
  final datos = await ref.read(apiProvider).get('/clientes-app', params: {'celular': celular});
  return datos['tiene_app'] == true ? datos['nombre'] as String? : null;
});

/// «Andre Méndez tiene la app. ¿Es él?». Encendido, la cita queda en su app, confirmada, y le llega el aviso.
class TarjetaClienteApp extends ConsumerWidget {
  const TarjetaClienteApp({super.key, required this.celular, required this.vincular, required this.alCambiar});

  final String celular;
  final bool vincular;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numero = celularCompleto(celular);
    if (numero == null) return const SizedBox.shrink();
    final cuenta = ref.watch(cuentaAppProvider(numero)).valueOrNull;
    if (cuenta == null) return const SizedBox.shrink();
    final tonos = context.tonos;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        key: const Key('tarjeta-cliente-app'),
        decoration: BoxDecoration(
          color: Paleta.frambuesa.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Paleta.frambuesa.withValues(alpha: 0.25)),
        ),
        child: SwitchListTile(
          key: const Key('vincular-app'),
          value: vincular,
          onChanged: alCambiar,
          secondary: const Icon(Icons.phone_iphone_rounded, color: Paleta.frambuesa),
          title: Text('$cuenta tiene la app. ¿Es esta persona?', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            vincular
                ? 'La cita aparecerá en su app, ya confirmada, y le llegará una notificación.'
                : 'No se vincula: solo podrás avisarle por WhatsApp.',
            style: TextStyle(color: tonos.textoSuave),
          ),
        ),
      ),
    );
  }
}
