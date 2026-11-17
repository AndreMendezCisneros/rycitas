import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/diseno/notas.dart';
import '../../shared/diseno/paleta.dart';
import '../../shared/diseno/vidrio.dart';
import '../../shared/modelos.dart';
import '../agenda/agenda_controlador.dart';
import '../configuracion/tratamientos_pantalla.dart';
import '../pacientes/pacientes_pantalla.dart';
import 'selector_hora.dart';

/// Reserva rápida: todo en una hoja flotante, sin cambiar de pantalla. Cliente (buscado o nuevo), servicio y la
/// hora libre más próxima ya elegida: en el caso común son 3 toques y «Reservar».
/// [dia] y [hora] llegan al tocar un día del calendario o mantener pulsado un hueco libre de la agenda.
Future<void> abrirReservaRapida(BuildContext context, WidgetRef ref, {DateTime? dia, String? hora}) {
  HapticFeedback.lightImpact();
  return mostrarHojaVidrio<void>(
    context,
    altoCompleto: true,
    builder: (_) => ReservaRapida(dia: dia, hora: hora),
  );
}

class ReservaRapida extends ConsumerStatefulWidget {
  const ReservaRapida({super.key, this.dia, this.hora});

  final DateTime? dia;
  final String? hora;

  @override
  ConsumerState<ReservaRapida> createState() => _ReservaRapidaState();
}

class _ReservaRapidaState extends ConsumerState<ReservaRapida> {
  final _buscar = TextEditingController();
  final _nombre = TextEditingController();
  final _celular = TextEditingController();
  final _notas = TextEditingController();
  Timer? _espera;
  String _consulta = '';
  Paciente? _paciente;
  bool _nuevo = false;

  Tratamiento? _tratamiento;
  ProfesionalNegocio? _profesional;
  String? _fecha;
  String? _inicio;
  bool _verTodas = false;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fecha = widget.dia == null ? null : Fechas.fechaApi(widget.dia!);
    _inicio = widget.hora;
  }

  @override
  void dispose() {
    _espera?.cancel();
    for (final c in [_buscar, _nombre, _celular, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _consulta = texto.trim());
    });
  }

  void _elegirPaciente(Paciente p) {
    HapticFeedback.selectionClick();
    setState(() {
      _paciente = p;
      _nuevo = false;
      _nombre.text = p.nombre;
      _celular.text = p.celular;
    });
  }

  List<ProfesionalNegocio> _opcionesQuien(Negocio negocio) {
    final t = _tratamiento;
    if (t == null || !negocio.esGeneral || !negocio.porProfesional) return const [];
    final quienes = negocio.profesionales.where((p) => p.hace(t.id!)).toList();
    return quienes.length > 1 ? quienes : const [];
  }

  bool get _listo =>
      _tratamiento != null && _inicio != null && _nombre.text.trim().isNotEmpty && _celular.text.trim().isNotEmpty;

  Future<void> _reservar() async {
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
        if (_notas.text.trim().isNotEmpty) 'notas': _notas.text.trim(),
      });
      ref.read(agendaProvider.notifier).aplicarAgenda(datos['agenda'] as Map<String, dynamic>);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      final navegador = Navigator.of(context);
      final contextoRaiz = navegador.context;
      navegador.pop();
      if (contextoRaiz.mounted) {
        await ofrecerAviso(contextoRaiz, 'Cita registrada', datos['whatsapp_url'] as String?);
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        if (e.codigo == 'horario_tomado' || e.codigo == 'paciente_ocupado') {
          ref.invalidate(horasLibresProvider);
          _inicio = null;
        }
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActualProvider);
    final voc = negocio.voc;
    final textos = Theme.of(context).textTheme;
    final quienes = _opcionesQuien(negocio);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: Paleta.degradado, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Reserva rápida', style: textos.titleLarge)),
              TextButton(
                key: const Key('formulario-completo'),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push('/nueva-cita');
                },
                child: const Text('Paso a paso'),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Paso(numero: 1, titulo: '¿Para quién?', listo: _nombre.text.isNotEmpty && _celular.text.isNotEmpty),
                _pasoCliente(voc),
                const SizedBox(height: 18),
                _Paso(numero: 2, titulo: Vocabulario.may(voc.servicio), listo: _tratamiento != null),
                _pasoServicio(),
                if (quienes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Cualquiera'),
                        selected: _profesional == null,
                        onSelected: (_) => setState(() {
                          _profesional = null;
                          _inicio = null;
                        }),
                      ),
                      for (final p in quienes)
                        ChoiceChip(
                          label: Text(p.nombre),
                          selected: _profesional?.id == p.id,
                          onSelected: (_) => setState(() {
                            _profesional = p;
                            _inicio = null;
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                _Paso(numero: 3, titulo: 'Hora', listo: _inicio != null),
                if (_tratamiento == null)
                  Text(
                    'Elige primero el ${voc.servicio}.',
                    style: textos.bodyMedium?.copyWith(color: Paleta.textoSuave),
                  )
                else
                  _pasoHora(),
                const SizedBox(height: 18),
                CampoNotas(controlador: _notas, rubro: negocio.rubro, etiqueta: 'Notas (lo que pidió, detalles…)'),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('reservar-rapido'),
              onPressed: _listo && !_enviando ? _reservar : null,
              icon: _enviando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(
                _inicio == null ? 'Reservar' : 'Reservar · ${Fechas.diaHora(_inicio!)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pasoCliente(Vocabulario voc) {
    if (_paciente != null || _nuevo) {
      return Column(
        children: [
          if (_paciente != null)
            Card(
              child: ListTile(
                leading: Avatar(_paciente!.nombre, radio: 20),
                title: Text(_paciente!.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_paciente!.celular),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    _paciente = null;
                    _nombre.clear();
                    _celular.clear();
                  }),
                  child: const Text('Cambiar'),
                ),
              ),
            )
          else ...[
            TextField(
              key: const Key('rapida-nombre'),
              controller: _nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'Nombre del ${voc.cliente}'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('rapida-celular'),
              controller: _celular,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Celular', hintText: '987 654 321', prefixText: '+51 '),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _nuevo = false),
                icon: const Icon(Icons.search_rounded),
                label: Text('Buscar un ${voc.cliente} existente'),
              ),
            ),
          ],
        ],
      );
    }
    final resultados = _consulta.length < 2 ? null : ref.watch(busquedaPacientesProvider(_consulta));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('rapida-buscar'),
          controller: _buscar,
          onChanged: _alEscribir,
          decoration: InputDecoration(
            hintText: 'Busca por nombre o celular',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _buscar.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() {
                      _buscar.clear();
                      _consulta = '';
                    }),
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (resultados != null)
          resultados.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Text('No se pudo buscar: $e'),
            data: (lista) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in lista.take(6))
                  ActionChip(
                    avatar: Avatar(p.nombre, radio: 12),
                    label: Text(p.nombre),
                    onPressed: () => _elegirPaciente(p),
                  ),
                if (lista.isEmpty) Text('Nadie con «$_consulta».', style: const TextStyle(color: Paleta.textoSuave)),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('rapida-nuevo'),
            onPressed: () => setState(() {
              _nuevo = true;
              final q = _buscar.text.trim();
              if (RegExp(r'^[\d +]+$').hasMatch(q)) {
                _celular.text = q;
              } else {
                _nombre.text = q;
              }
            }),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text('${Vocabulario.may(voc.cliente)} nuevo'),
          ),
        ),
      ],
    );
  }

  Widget _pasoServicio() {
    final tratamientos = ref.watch(tratamientosProvider);
    return tratamientos.when(
      loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(tratamientosProvider)),
      data: (lista) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in lista)
            ChoiceChip(
              key: Key('rapida-servicio-${t.id}'),
              label: Text('${t.nombre} · ${t.duracionMin} min'),
              selected: _tratamiento?.id == t.id,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() {
                  _tratamiento = t;
                  _profesional = null;
                  _inicio = widget.hora; // la hora del hueco se conserva si sigue libre
                  _verTodas = false;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _pasoHora() {
    final consulta = (tratamientoId: _tratamiento!.id!, excluirCita: null, profesionalId: _profesional?.id);
    final libres = ref.watch(horasLibresProvider(consulta));
    return libres.when(
      loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
      error: (e, _) => ErrorConReintento(error: e, alReintentar: () => ref.invalidate(horasLibresProvider(consulta))),
      data: (dias) {
        if (dias.isEmpty) return const Text('No hay horas libres en los próximos 30 días.');
        final indice = _fecha == null ? 0 : dias.indexWhere((d) => d.fecha == _fecha);
        final dia = dias[indice < 0 ? 0 : indice];
        // Lo más pronto queda elegido de entrada (si la hora del hueco no está libre, también).
        if (_inicio == null || !dias.any((d) => d.horas.contains(_inicio))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && dia.horas.isNotEmpty && (_inicio == null || !dias.any((d) => d.horas.contains(_inicio)))) {
              setState(() => _inicio = dia.horas.first);
            }
          });
        }
        final grupos = <String, List<String>>{};
        for (final h in dia.horas) {
          final hh = Fechas.enLima(h).hour;
          grupos
              .putIfAbsent(
                hh < 12
                    ? 'Mañana'
                    : hh < 18
                    ? 'Tarde'
                    : 'Noche',
                () => [],
              )
              .add(h);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (indice < 0 && _fecha != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ese día no tiene horas libres; te mostramos el más cercano.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Paleta.ambarTexto),
                ),
              ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(Fechas.diaCorto(dias[i].fecha)),
                  selected: dias[i].fecha == dia.fecha,
                  onSelected: (_) => setState(() {
                    _fecha = dias[i].fecha;
                    _inicio = dias[i].horas.isEmpty ? null : dias[i].horas.first;
                    _verTodas = false;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final MapEntry(key: nombre, value: horas) in grupos.entries) ...[
              Text(nombre, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Paleta.textoSuave)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in _verTodas ? horas : horas.take(7))
                    ChoiceChip(
                      label: Text(Fechas.hora(h)),
                      selected: _inicio == h,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _inicio = h);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (!_verTodas && grupos.values.any((h) => h.length > 7))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _verTodas = true),
                  child: const Text('Ver más horas'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.titulo, required this.listo});

  final int numero;
  final String titulo;
  final bool listo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: listo ? Paleta.degradado : null,
            color: listo ? null : Paleta.rosa,
          ),
          child: Center(
            child: listo
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text(
                    '$numero',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.frambuesa, fontSize: 13),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
