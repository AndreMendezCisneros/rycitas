import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fidelizacion/fidelizacion_pantallas.dart';
import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';

final busquedaPacientesProvider = FutureProvider.autoDispose
    .family<List<Paciente>, String>((ref, q) async {
      final datos = await ref
          .read(apiProvider)
          .get('/pacientes', params: {'q': q});
      return (datos['pacientes'] as List)
          .map((p) => Paciente.fromJson(p as Map<String, dynamic>))
          .toList();
    });

final pacienteProvider = FutureProvider.autoDispose.family<Paciente, int>((
  ref,
  id,
) async {
  return Paciente.fromJson(await ref.read(apiProvider).get('/pacientes/$id'));
});

class PacientesPantalla extends ConsumerStatefulWidget {
  const PacientesPantalla({super.key});

  @override
  ConsumerState<PacientesPantalla> createState() => _PacientesPantallaState();
}

class _PacientesPantallaState extends ConsumerState<PacientesPantalla> {
  String _consulta = '';
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _consulta = texto.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pacientes = ref.watch(busquedaPacientesProvider(_consulta));
    return Scaffold(
      appBar: AppBar(title: Text(Vocabulario.may(vocDe(context).clientes))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: _alEscribir,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o celular',
              ),
            ),
          ),
          Expanded(
            child: pacientes.when(
              loading: () => const Cargando(),
              // En listas desplazables: con el teclado abierto queda poco alto y una columna fija desbordaría.
              error: (e, _) => ListView(
                children: [
                  ErrorConReintento(
                    error: e,
                    alReintentar: () =>
                        ref.invalidate(busquedaPacientesProvider(_consulta)),
                  ),
                ],
              ),
              data: (lista) => lista.isEmpty
                  ? ListView(
                      children: [
                        Vacio(
                          'No encontramos ${vocDe(context).clientes}.',
                          icono: Icons.person_search_rounded,
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        for (final p in lista)
                          ListTile(
                            title: Text(p.nombre),
                            subtitle: Text(
                              '${p.celular}'
                              '${p.inasistencias > 0 ? ' · ${p.inasistencias} inasistencias' : ''}'
                              '${p.bloqueado ? ' · bloqueado' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/pacientes/${p.id}'),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PacienteDetallePantalla extends ConsumerWidget {
  const PacienteDetallePantalla({super.key, required this.id});

  final int id;

  Future<void> _cambiarBloqueo(
    BuildContext context,
    WidgetRef ref,
    Paciente p,
  ) async {
    if (!p.bloqueado) {
      final ok = await confirmar(
        context,
        '¿Bloquear este número?',
        'No podrá reservar en línea. No se le avisará.',
        accion: 'Bloquear',
      );
      if (!ok) return;
    }
    try {
      await ref.read(apiProvider).post('/pacientes/$id/bloquear', {
        'bloqueado': !p.bloqueado,
      });
      ref.invalidate(pacienteProvider(id));
    } on ApiError catch (e) {
      if (context.mounted) avisar(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paciente = ref.watch(pacienteProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(Vocabulario.may(vocDe(context).cliente))),
      body: paciente.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(
          error: e,
          alReintentar: () => ref.invalidate(pacienteProvider(id)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(p.nombre, style: Theme.of(context).textTheme.headlineSmall),
            Text(p.celular),
            const SizedBox(height: 8),
            Text('${p.inasistencias} inasistencias · ${p.citas.length} citas'),
            const SizedBox(height: 12),
            TarjetaDelCliente(pacienteId: id),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _cambiarBloqueo(context, ref, p),
              child: Text(
                p.bloqueado ? 'Desbloquear número' : 'Bloquear número',
              ),
            ),
            const SizedBox(height: 24),
            Text('Historial', style: Theme.of(context).textTheme.titleMedium),
            if (p.citas.isEmpty) const Vacio('Sin citas todavía.'),
            for (final c in p.citas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.tratamiento.nombre),
                subtitle: Text(Fechas.diaHora(c.inicio)),
                trailing: Text(c.estadoTexto),
              ),
          ],
        ),
      ),
    );
  }
}
