import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/negocio.dart';
import '../../core/api.dart';
import '../../shared/comunes.dart';
import '../auth/bloqueo.dart';
import '../auth/sesion.dart';

class AjustesPantalla extends ConsumerWidget {
  const AjustesPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.read(sesionProvider.notifier);
    final negocio = ref.watch(negocioActualProvider);
    ref.watch(bloqueoProvider);
    final bloqueo = ref.read(bloqueoProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(negocio.nombre.isEmpty ? 'Ajustes' : negocio.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Avatar(sesion.correo ?? negocio.nombre, radio: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu cuenta', style: Theme.of(context).textTheme.labelMedium),
                        Text(
                          sesion.correo ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _tipoDeCuenta(negocio),
                          key: const Key('tipo-cuenta'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TituloGrupo('Tu negocio'),
          _Grupo(
            children: [
              _Opcion(
                icono: Icons.insights_rounded,
                color: const Color(0xFF6366F1),
                titulo: 'Mi mes',
                detalle: 'Confirmaciones, inasistencias, ocupación',
                alTocar: () => context.push('/mi-mes'),
              ),
              _Opcion(
                icono: Icons.schedule_rounded,
                color: const Color(0xFF0EA5E9),
                titulo: 'Horario de atención',
                alTocar: () => context.push('/ajustes/horario'),
              ),
              if (negocio.esGeneral)
                _Opcion(
                  icono: Icons.view_agenda_rounded,
                  color: const Color(0xFFF59E0B),
                  titulo: 'Turnos de la agenda',
                  detalle: negocio.turnos.map((t) => t.nombre).join(' · '),
                  alTocar: () => context.push('/ajustes/turnos'),
                ),
              _Opcion(
                icono: Icons.event_busy_rounded,
                color: const Color(0xFFF97316),
                titulo: 'Bloqueos',
                detalle: 'Vacaciones, congresos, imprevistos',
                alTocar: () => context.push('/ajustes/bloqueos'),
              ),
              _Opcion(
                icono: Icons.spa_rounded,
                color: const Color(0xFF14B8A6),
                titulo: Vocabulario.may(ref.watch(vocProvider).servicios),
                alTocar: () => context.push('/ajustes/tratamientos'),
              ),
            ],
          ),
          TituloGrupo('${Vocabulario.may(ref.watch(vocProvider).clientes)} que vuelven'),
          _Grupo(
            children: [
              _Opcion(
                key: const Key('ajuste-fidelidad'),
                icono: Icons.loyalty_rounded,
                color: const Color(0xFFEC4899),
                titulo: 'Tarjeta de sellos',
                detalle: 'Un sello por visita y un premio al completarla',
                alTocar: () => context.push('/ajustes/fidelidad'),
              ),
              if (negocio.esGeneral) ...[
                _Opcion(
                  key: const Key('ajuste-cupones'),
                  icono: Icons.local_offer_rounded,
                  color: const Color(0xFF8B5CF6),
                  titulo: 'Cupones de descuento',
                  alTocar: () => context.push('/ajustes/cupones'),
                ),
                _Opcion(
                  key: const Key('ajuste-campanas'),
                  icono: Icons.campaign_rounded,
                  color: const Color(0xFF10B981),
                  titulo: 'Enviar una promoción',
                  detalle: 'Aviso en la app y WhatsApp para el resto',
                  alTocar: () => context.push('/ajustes/campanas'),
                ),
              ],
            ],
          ),
          const TituloGrupo('Seguridad'),
          _Grupo(
            children: [
              _Opcion(
                icono: Icons.notifications_active_rounded,
                color: const Color(0xFFEF4444),
                titulo: 'Notificaciones',
                detalle: 'Antes de cada cita, reservas nuevas, agenda de mañana',
                alTocar: () => context.push('/ajustes/avisos'),
              ),
              SwitchListTile(
                key: const Key('bloqueo'),
                secondary: const _Icono(icono: Icons.fingerprint_rounded, color: Color(0xFF22C55E)),
                title: const Text('Pedir huella o PIN'),
                subtitle: const Text('Al abrir la app y al volver después de 5 min'),
                value: bloqueo.activo,
                onChanged: (valor) async {
                  final error = await bloqueo.cambiar(valor);
                  if (error != null && context.mounted) avisar(context, error);
                },
              ),
              _Opcion(
                icono: Icons.devices_other_rounded,
                color: const Color(0xFF64748B),
                titulo: 'Cerrar sesión en todos los equipos',
                detalle: 'Si perdiste un teléfono o alguien más entró con tu cuenta',
                flecha: false,
                alTocar: () async {
                  final ok = await confirmar(
                    context,
                    '¿Cerrar sesión en todos los equipos?',
                    'Tendrás que volver a entrar con tu correo y contraseña en cada teléfono, también en este.',
                    accion: 'Cerrar en todos',
                  );
                  if (!ok) return;
                  try {
                    await ref.read(apiProvider).post('/auth/cerrar-todas');
                    await sesion.cerrar();
                  } on ApiError catch (e) {
                    if (context.mounted) avisar(context, e.mensaje);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: sesion.cerrar,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'RyCitas',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Cuenta general: ve a todo el equipo» o «Solo tu agenda (Lic. Ana)».
String _tipoDeCuenta(Negocio negocio) {
  if (negocio.esGeneral) {
    return negocio.porProfesional ? 'Cuenta general: ve las citas de todo el equipo' : 'Cuenta general';
  }
  final mio = negocio.profesionales.where((p) => p.id == negocio.miProfesionalId).firstOrNull;
  return 'Solo tu agenda${mio == null ? '' : ' (${mio.nombre})'}';
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 68),
          children[i],
        ],
      ],
    ),
  );
}

class _Icono extends StatelessWidget {
  const _Icono({required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
    child: Icon(icono, color: color, size: 21),
  );
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.alTocar,
    this.detalle,
    this.flecha = true,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String? detalle;
  final VoidCallback alTocar;
  final bool flecha;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _Icono(icono: icono, color: color),
    title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: detalle == null ? null : Text(detalle!),
    trailing: flecha ? const Icon(Icons.chevron_right_rounded) : null,
    onTap: alTocar,
  );
}
