import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import 'datos_cliente.dart';
import 'widgets_cliente.dart';

/// «Mis citas»: próximas e historial, en todos los lugares. Cancelar o mover lo hace el negocio: se le escribe.
class MisCitasPantalla extends ConsumerWidget {
  const MisCitasPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(misCitasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(misCitasProvider)),
        data: (d) {
          final proximas = lista(d['proximas']);
          final pasadas = lista(d['pasadas']);
          if (proximas.isEmpty && pasadas.isEmpty) {
            return const AvisoSuave(
              icono: Icons.event_note_rounded,
              texto: 'Todavía no tienes citas. ¡Reserva la primera!',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(misCitasProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (proximas.isNotEmpty) const TituloGrupo('Próximas'),
                for (final c in proximas) _CitaCliente(cita: c),
                if (pasadas.isNotEmpty) const TituloGrupo('Anteriores'),
                for (final c in pasadas) _CitaCliente(cita: c, pasada: true),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CitaCliente extends StatelessWidget {
  const _CitaCliente({required this.cita, this.pasada = false});

  final Json cita;
  final bool pasada;

  @override
  Widget build(BuildContext context) {
    final negocio = cita['negocio'] as Json;
    final lugar = cita['consultorio'] as Json;
    final cupon = cita['cupon'] as Json?;
    final whatsapp = lugar['whatsapp'] as String? ?? '';
    final texto =
        'Hola, soy ${cita['paciente']}. Sobre mi cita de ${cita['tratamiento']} del '
        '${Fechas.diaHora(cita['inicio'] as String)}: ';
    return Card(
      key: Key('cita-cliente-${cita['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(negocio['nombre'] as String, style: Theme.of(context).textTheme.titleMedium)),
                ChipEstado(estado: cita['estado'] as String, texto: cita['estado_texto'] as String),
              ],
            ),
            const SizedBox(height: 4),
            Text('${cita['tratamiento']} · con ${cita['profesional']}'),
            Text(Fechas.diaHora(cita['inicio'] as String), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (cita['hora_estimada'] != null && (cita['retraso_min'] as int? ?? 0) > 0)
              Text(
                'Van con ${cita['retraso_min']} min de retraso: te atienden cerca de las '
                '${Fechas.hora(cita['hora_estimada'] as String)}.',
              ),
            if (cupon != null) Text('Cupón ${cupon['codigo']} · ${cupon['descuento']}'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                if (pasada)
                  ActionChip(
                    avatar: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Volver a reservar'),
                    onPressed: () => context.push('/cliente/negocio/${negocio['slug']}'),
                  )
                else if ((lugar['mapa_url'] as String? ?? '').isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Cómo llegar'),
                    onPressed: () => abrirEnlace(context, lugar['mapa_url'] as String),
                  ),
                if (!pasada && whatsapp.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Escribir'),
                    onPressed: () =>
                        abrirWhatsapp(context, 'https://wa.me/$whatsapp?text=${Uri.encodeComponent(texto)}'),
                  ),
                if (!pasada)
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Ver detalle'),
                    onPressed: () => abrirEnlace(context, '$apiUrl${cita['enlace']}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «Beneficios»: tarjetas de sellos, cupones y el código para invitar.
class BeneficiosPantalla extends ConsumerWidget {
  const BeneficiosPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(beneficiosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Beneficios')),
      body: datos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(beneficiosProvider)),
        data: (d) {
          final tarjetas = lista(d['tarjetas']);
          final cupones = lista(d['cupones']);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(beneficiosProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (cupones.isNotEmpty) const TituloGrupo('Cupones'),
                for (final c in cupones)
                  TarjetaCupon(
                    cupon: c,
                    negocio: (c['negocio'] as Json)['nombre'] as String,
                    alUsar: () => context.push('/cliente/negocio/${(c['negocio'] as Json)['slug']}'),
                  ),
                if (tarjetas.isNotEmpty) const TituloGrupo('Tarjetas de sellos'),
                for (final t in tarjetas)
                  TarjetaSellos(tarjeta: t, negocio: (t['negocio'] as Json)['nombre'] as String),
                if (tarjetas.isEmpty && cupones.isEmpty)
                  const AvisoSuave(
                    icono: Icons.loyalty_rounded,
                    texto:
                        'Cuando un lugar donde te atiendes tenga tarjeta de sellos o te mande un cupón, lo verás aquí.',
                  ),
                const SizedBox(height: 8),
                TarjetaInvitar(codigo: d['codigo_referido'] as String),
              ],
            ),
          );
        },
      ),
    );
  }
}
