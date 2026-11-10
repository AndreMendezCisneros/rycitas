import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';

final tratamientosProvider = FutureProvider.autoDispose<List<Tratamiento>>((ref) async {
  final datos = await ref.read(apiProvider).get('/tratamientos');
  return (datos['tratamientos'] as List).map((t) => Tratamiento.fromJson(t as Map<String, dynamic>)).toList();
});

class TratamientosPantalla extends ConsumerWidget {
  const TratamientosPantalla({super.key});

  Future<void> _abrir(BuildContext context, WidgetRef ref, Tratamiento? tratamiento) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FormularioTratamiento(tratamiento: tratamiento)));
    ref.invalidate(tratamientosProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tratamientos = ref.watch(tratamientosProvider);
    return Scaffold(
      appBar: AppBar(title: Text(Vocabulario.may(vocDe(context).servicios))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: tratamientos.when(
        loading: () => const Cargando(),
        error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(tratamientosProvider)),
        data: (lista) => lista.isEmpty
            ? Vacio('Agrega tu primer ${vocDe(context).servicio}.')
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final t in lista)
                    ListTile(
                      title: Text(t.nombre),
                      subtitle: Text(
                        '${t.duracionMin} min + ${t.margenMin} de margen'
                        '${t.precioDesde == null ? '' : ' · desde S/ ${t.precioDesde}'}'
                        '${t.reservable ? '' : ' · no se reserva en línea'}'
                        '${t.duracionRealMin == null ? '' : '\nEn la práctica: ${t.duracionRealMin} min'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(context, ref, t),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FormularioTratamiento extends ConsumerStatefulWidget {
  const _FormularioTratamiento({this.tratamiento});

  final Tratamiento? tratamiento;

  @override
  ConsumerState<_FormularioTratamiento> createState() => _FormularioTratamientoState();
}

class _FormularioTratamientoState extends ConsumerState<_FormularioTratamiento> {
  late final _nombre = TextEditingController(text: widget.tratamiento?.nombre);
  late final _motivo = TextEditingController(text: widget.tratamiento?.motivoPaciente);
  late final _duracion = TextEditingController(text: '${widget.tratamiento?.duracionMin ?? 30}');
  late final _margen = TextEditingController(text: '${widget.tratamiento?.margenMin ?? 0}');
  late final _precio = TextEditingController(text: widget.tratamiento?.precioDesde);
  late final _indicaciones = TextEditingController(text: widget.tratamiento?.indicaciones);
  late bool _reservable = widget.tratamiento?.reservable ?? true;
  late bool _visible = widget.tratamiento?.visible ?? true;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _motivo, _duracion, _margen, _precio, _indicaciones]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final precio = _precio.text.trim().replaceAll(',', '.');
    if (precio.isNotEmpty && double.tryParse(precio) == null) {
      avisar(context, 'Escribe el precio solo con números.');
      return;
    }
    final cuerpo = {
      'nombre': _nombre.text.trim(),
      'motivo_paciente': _motivo.text.trim(),
      'descripcion': widget.tratamiento?.descripcion ?? '',
      'indicaciones': _indicaciones.text.trim(),
      'duracion_min': int.tryParse(_duracion.text) ?? 0,
      'margen_min': int.tryParse(_margen.text) ?? 0,
      'precio_desde': precio.isEmpty ? null : precio,
      'reservable': _reservable,
      'visible': _visible,
      'orden': widget.tratamiento?.orden ?? 0,
    };
    setState(() => _enviando = true);
    try {
      final api = ref.read(apiProvider);
      final id = widget.tratamiento?.id;
      id == null ? await api.post('/tratamientos', cuerpo) : await api.put('/tratamientos/$id', cuerpo);
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _borrar() async {
    final ok = await confirmar(
      context,
      '¿Quitar ${widget.tratamiento!.nombre}?',
      'Si ya tiene citas, solo dejará de mostrarse; el historial se conserva.',
      accion: 'Quitar',
    );
    if (!ok) return;
    try {
      await ref.read(apiProvider).delete('/tratamientos/${widget.tratamiento!.id}');
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) avisar(context, e.mensaje);
    }
  }

  /// Lo aprendido con Iniciar y Terminar: cuánto dura de verdad, para ajustar la duración con un toque.
  List<Widget> _duracionReal() {
    final real = widget.tratamiento?.duracionRealMin;
    if (real == null) return const [];
    final n = widget.tratamiento!.duracionRealCitas;
    final igual = int.tryParse(_duracion.text) == real;
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text('En la práctica dura $real min ($n cita${n == 1 ? '' : 's'}).')),
          if (!igual)
            TextButton(
              onPressed: () => setState(() => _duracion.text = '$real'),
              child: const Text('Usar este tiempo'),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final soloNumeros = [FilteringTextInputFormatter.digitsOnly];
    const separador = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tratamiento == null ? 'Nuevo tratamiento' : 'Editar tratamiento'),
        actions: [
          if (widget.tratamiento != null)
            IconButton(tooltip: 'Quitar', onPressed: _borrar, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          separador,
          TextField(
            controller: _motivo,
            decoration: InputDecoration(
              labelText: 'Motivo que ve el ${vocDe(context).cliente}',
              hintText: 'Por ejemplo: Tengo dolor',
            ),
          ),
          separador,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _duracion,
                  keyboardType: TextInputType.number,
                  inputFormatters: soloNumeros,
                  decoration: const InputDecoration(labelText: 'Duración (min)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _margen,
                  keyboardType: TextInputType.number,
                  inputFormatters: soloNumeros,
                  decoration: const InputDecoration(labelText: 'Margen (min)'),
                ),
              ),
            ],
          ),
          ..._duracionReal(),
          separador,
          TextField(
            controller: _indicaciones,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Indicaciones para el ${vocDe(context).cliente}',
              hintText: 'Por ejemplo: Ven 10 min antes',
              helperText: 'Van en el WhatsApp de confirmación y en el recordatorio.',
            ),
          ),
          separador,
          TextField(
            controller: _precio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Precio desde (S/)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Se reserva en línea'),
            value: _reservable,
            onChanged: (v) => setState(() => _reservable = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Se muestra en el sitio'),
            value: _visible,
            onChanged: (v) => setState(() => _visible = v),
          ),
          separador,
          FilledButton(onPressed: _enviando ? null : _guardar, child: Text(_enviando ? 'Guardando…' : 'Guardar')),
        ],
      ),
    );
  }
}
