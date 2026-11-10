import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';
import 'acciones_cita.dart';

final porAprobarProvider = FutureProvider.autoDispose<List<Cita>>((ref) async {
  final datos = await ref.read(apiProvider).get('/citas/por-aprobar');
  return (datos['citas'] as List).map((c) => Cita.fromJson(c as Map<String, dynamic>)).toList();
});

/// Reservas del sitio que esperan al doctor. «Confirmar y avisar» confirma la cita y abre WhatsApp con el
/// mensaje ya escrito para el paciente: sin API de WhatsApp y sin costo (RF-29, RF-30).
class PorAprobarPantalla extends ConsumerWidget {
  const PorAprobarPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citas = ref.watch(porAprobarProvider);
    final negocio = ref.watch(negocioActualProvider);
    void recargar() => ref.invalidate(porAprobarProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Por confirmar')),
      body: citas.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: recargar),
        data: (lista) => lista.isEmpty
            ? const Vacio('No hay reservas por confirmar. ¡Todo al día!', icono: Icons.done_all_rounded)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final textos = Theme.of(context).textTheme;
                  final esquema = Theme.of(context).colorScheme;
                  if (i == 0) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: esquema.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: esquema.primary, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Al confirmar se abre WhatsApp con el mensaje listo. Solo tienes que tocar Enviar. '
                              'Si el número no responde, puedes rechazar la reserva y el horario queda libre.',
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final c = lista[i - 1];
                  Widget dato(IconData icono, String texto) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(icono, size: 18, color: esquema.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(child: Text(texto, style: textos.bodyMedium)),
                      ],
                    ),
                  );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Avatar(c.paciente.nombre),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.paciente.nombre, style: textos.titleMedium),
                                    Text(
                                      c.paciente.inasistencias > 0
                                          ? '${c.paciente.celular} · ${c.paciente.inasistencias} inasistencia${c.paciente.inasistencias == 1 ? '' : 's'}'
                                          : c.paciente.celular,
                                      style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const ChipEstado(estado: 'por_aprobar', texto: 'Nueva'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          dato(Icons.spa_outlined, c.tratamiento.nombre),
                          dato(Icons.event_rounded, Fechas.diaHora(c.inicio)),
                          if (negocio.porProfesional && negocio.esGeneral && c.profesional != null)
                            dato(Icons.person_outline_rounded, 'Con ${c.profesional!.nombre}'),
                          if (c.cupon != null)
                            dato(Icons.local_offer_outlined, 'Cupón ${c.cupon!.codigo}: ${c.cupon!.titulo} (${c.cupon!.descuento})'),
                          if (c.tieneOferta)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Ofrece ${soles(c.precioOfrecido!)}'
                                '${c.precioReferencia == null ? '' : ' (referencia ${soles(c.precioReferencia!)})'}',
                                key: Key('oferta-${c.id}'),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  onPressed: () => ejecutarDecision(
                                    context,
                                    ref,
                                    c.id,
                                    'rechazar',
                                    'Reserva rechazada',
                                    alCambiar: recargar,
                                  ),
                                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Rechazar')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: FilledButton.icon(
                                  onPressed: () => confirmarCita(context, ref, c, alCambiar: recargar),
                                  icon: const Icon(Icons.chat_rounded),
                                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Confirmar y avisar')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
