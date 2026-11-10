import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/negocio.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';
import '../agenda/agenda_controlador.dart';
import '../configuracion/tratamientos_pantalla.dart';
import 'selector_hora.dart';

/// Cita por teléfono: servicio, con quién (si hay varios y la cuenta es general), hora libre y cliente (RF-23).
class NuevaCitaPantalla extends ConsumerStatefulWidget {
  const NuevaCitaPantalla({super.key});

  @override
  ConsumerState<NuevaCitaPantalla> createState() => _NuevaCitaPantallaState();
}

class _NuevaCitaPantallaState extends ConsumerState<NuevaCitaPantalla> {
  Tratamiento? _tratamiento;

  /// Ya se pasó por «¿Con quién?». [_profesional] null después de elegir: «Cualquiera».
  bool _quienElegido = false;
  ProfesionalNegocio? _profesional;
  String? _inicio;
  final _nombre = TextEditingController();
  final _celular = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _celular.dispose();
    super.dispose();
  }

  void _atras() {
    setState(() {
      _error = null;
      if (_inicio != null) {
        _inicio = null;
      } else if (_quienElegido && _opcionesQuien().isNotEmpty) {
        _quienElegido = false;
        _profesional = null;
      } else if (_tratamiento != null) {
        _tratamiento = null;
        _quienElegido = false;
        _profesional = null;
      } else {
        context.pop();
      }
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final datos = await ref.read(apiProvider).post('/citas', {
        'tratamiento_id': _tratamiento!.id,
        'inicio': _inicio,
        'nombre': _nombre.text.trim(),
        'celular': _celular.text.trim(),
        'profesional_id': ?_profesional?.id,
      });
      ref.read(agendaProvider.notifier).aplicarAgenda(datos['agenda'] as Map<String, dynamic>);
      if (mounted) {
        // Se le envía el enlace con su calendario: es su único recordatorio.
        await ofrecerAviso(context, 'Cita registrada', datos['whatsapp_url'] as String?);
      }
      if (mounted) context.pop();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        // Alguien tomó esa hora mientras se llenaba el formulario: de vuelta a elegir otra.
        // Alguien tomó esa hora, o el mismo número ya tiene otra cita a esa hora: de vuelta a elegir otra.
        if (e.codigo == 'horario_tomado' || e.codigo == 'paciente_ocupado') {
          ref.invalidate(horasLibresProvider);
          _inicio = null;
        }
      });
      if (e.codigo == 'horario_tomado' || e.codigo == 'paciente_ocupado') avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Profesionales que hacen el servicio elegido. Vacío: no hay nada que elegir (cuenta de un profesional,
  /// agenda compartida o uno solo que lo hace).
  List<ProfesionalNegocio> _opcionesQuien() {
    final negocio = ref.read(negocioActualProvider);
    final t = _tratamiento;
    if (t == null || !negocio.esGeneral || !negocio.porProfesional) return const [];
    final quienes = negocio.profesionales.where((p) => p.hace(t.id!)).toList();
    return quienes.length > 1 ? quienes : const [];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(negocioActualProvider);
    final conQuien = _opcionesQuien().isNotEmpty;
    final total = conQuien ? 4 : 3;
    final String paso;
    final Widget cuerpo;
    if (_tratamiento == null) {
      (paso, cuerpo) = ('1', _pasoTratamiento());
    } else if (conQuien && !_quienElegido) {
      (paso, cuerpo) = ('2', _pasoQuien());
    } else if (_inicio == null) {
      paso = conQuien ? '3' : '2';
      cuerpo = SelectorHora(
        key: ValueKey('horas-${_tratamiento!.id}-${_profesional?.id}'),
        consulta: (tratamientoId: _tratamiento!.id!, excluirCita: null, profesionalId: _profesional?.id),
        alElegir: (hora) => setState(() => _inicio = hora),
      );
    } else {
      (paso, cuerpo) = ('$total', _pasoPaciente());
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _atras),
        title: Text('Nueva cita · paso $paso de $total'),
      ),
      body: cuerpo,
    );
  }

  Widget _pasoQuien() {
    final voc = vocDe(context);
    final textos = Theme.of(context).textTheme;
    void elegir(ProfesionalNegocio? p) => setState(() {
      _profesional = p;
      _quienElegido = true;
    });
    return ListView(
      key: const Key('paso-quien'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('¿Con quién?', style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        ListTile(
          key: const Key('quien-cualquiera'),
          leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
          title: const Text('Cualquiera'),
          subtitle: Text('El primer ${voc.profesional} con la hora libre'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => elegir(null),
        ),
        for (final p in _opcionesQuien())
          ListTile(
            key: Key('quien-${p.id}'),
            leading: Avatar(p.nombre, radio: 20),
            title: Text(p.nombre),
            subtitle: p.detalle.isEmpty ? null : Text(p.detalle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => elegir(p),
          ),
      ],
    );
  }

  Widget _pasoTratamiento() {
    final tratamientos = ref.watch(tratamientosProvider);
    return tratamientos.when(
      loading: () => const Cargando(),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(tratamientosProvider)),
      data: (lista) => ListView(
        children: [
          for (final t in lista)
            ListTile(
              title: Text(t.nombre),
              subtitle: Text('${t.duracionMin} min'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _tratamiento = t),
            ),
        ],
      ),
    );
  }

  Widget _pasoPaciente() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(_tratamiento!.nombre),
            subtitle: Text(
              _profesional == null
                  ? Fechas.diaHora(_inicio!)
                  : '${Fechas.diaHora(_inicio!)} · con ${_profesional!.nombre}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: 'Nombre del ${vocDe(context).cliente}'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _celular,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Celular', hintText: '987 654 321', prefixText: '+51 '),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: _enviando ? null : _guardar, child: Text(_enviando ? 'Guardando…' : 'Registrar cita')),
      ],
    );
  }
}
