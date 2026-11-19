import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/diseno/tonos.dart';
import '../citas/selector_hora.dart';
import 'datos_cliente.dart';

/// Explica por qué hoy no aparece entre los días con horas, en vez de saltar al día siguiente sin decir nada.
class AvisoHoy extends ConsumerWidget {
  const AvisoHoy({super.key, required this.consulta});

  final ConsultaCliente consulta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(disponibilidadClienteProvider(consulta)).valueOrNull;
    final motivo = datos?['motivo_hoy'] as String?;
    if (datos == null || motivo == null) return const SizedBox.shrink();
    final horas = datos['anticipacion_horas'];
    final whatsapp = datos['whatsapp'] as String? ?? '';
    final texto = switch (motivo) {
      'anticipacion' =>
        'Para hoy ya no quedan horas: este lugar pide reservar con al menos $horas h de anticipación. '
            'Si es urgente, escríbele por WhatsApp.',
      'lleno' => 'Hoy ya está todo ocupado. Te mostramos los próximos días.',
      _ => 'Hoy ya cerró o no atiende. Te mostramos los próximos días.',
    };
    final tonos = context.tonos;
    return Container(
      key: const Key('aviso-hoy'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: tonos.ambarFondo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: tonos.ambarTexto),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: tonos.ambarTexto, fontWeight: FontWeight.w600),
            ),
          ),
          if (motivo == 'anticipacion' && whatsapp.isNotEmpty)
            TextButton(
              onPressed: () => abrirWhatsapp(
                context,
                'https://wa.me/$whatsapp?text=${Uri.encodeComponent('Hola, ¿tienen una hora libre para hoy?')}',
              ),
              child: const Text('Escribir'),
            ),
        ],
      ),
    );
  }
}

/// «Cancelar»: confirma y avisa al negocio. Devuelve true si se canceló.
Future<bool> cancelarCitaCliente(BuildContext context, WidgetRef ref, Json cita) async {
  final ok = await confirmar(
    context,
    '¿Cancelar tu cita?',
    'Le avisaremos a ${(cita['negocio'] as Json)['nombre']} y el horario quedará libre.',
    accion: 'Cancelar cita',
  );
  if (!ok || !context.mounted) return false;
  return _enviar(context, ref, '/mis-citas/${cita['id']}/cancelar', null, 'Listo, tu cita fue cancelada.');
}

/// «Reprogramar»: elige otra hora libre; la nueva queda por confirmar. Devuelve true si se movió.
Future<bool> reprogramarCitaCliente(BuildContext context, WidgetRef ref, Json cita) async {
  final negocio = cita['negocio'] as Json;
  final motivo = cita['motivo'] as String?;
  if (motivo == null) return false;
  final consulta = (slug: negocio['slug'] as String, motivo: motivo, profesional: cita['profesional_id'] as int?);
  final hora = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Elige la nueva hora')),
        body: Builder(
          builder: (pantalla) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              AvisoHoy(consulta: consulta),
              Expanded(
                child: SelectorHora(
                  key: const Key('reprogramar-hora'),
                  fuente: horasClienteProvider(consulta),
                  alElegir: (h) => Navigator.of(pantalla).pop(h),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (hora == null || !context.mounted) return false;
  final ok = await confirmar(
    context,
    '¿Mover tu cita al ${Fechas.diaHora(hora)}?',
    '${negocio['nombre']} debe confirmar la nueva hora. Te avisaremos con una notificación.',
    accion: 'Mover cita',
  );
  if (!ok || !context.mounted) return false;
  return _enviar(context, ref, '/mis-citas/${cita['id']}/reprogramar', {
    'inicio': hora,
  }, 'Listo: pediste la nueva hora. Te avisaremos cuando la confirmen.');
}

Future<bool> _enviar(BuildContext context, WidgetRef ref, String ruta, Json? cuerpo, String exito) async {
  try {
    await ref.read(apiClienteProvider).post(ruta, cuerpo);
    HapticFeedback.mediumImpact();
    refrescarCliente(ref);
    if (context.mounted) avisar(context, exito);
    return true;
  } on ApiError catch (e) {
    if (context.mounted) avisar(context, e.mensaje);
    return false;
  }
}
