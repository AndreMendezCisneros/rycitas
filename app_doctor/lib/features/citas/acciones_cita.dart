import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../core/negocio.dart';
import '../../shared/comunes.dart';
import '../../shared/modelos.dart';
import '../agenda/agenda_controlador.dart';
import 'selector_hora.dart';

/// Hoja con lo que se puede hacer con una cita: confirmar, escribir, llamar, mover o cancelar (RF-30).
Future<void> mostrarAccionesCita(
  BuildContext context,
  WidgetRef ref,
  Cita cita, {
  VoidCallback? alCambiar,
}) async {
  final puedeCambiar = cita.programada || cita.porAprobar;
  final negocio = ref.read(negocioActualProvider);
  final voc = negocio.voc;
  final detalle = [
    '${cita.tratamiento.nombre} · ${Fechas.diaHora(cita.inicio)}',
    if (negocio.porProfesional && cita.profesional != null)
      'Con ${cita.profesional!.nombre}',
    if (cita.precioTexto != null) cita.precioTexto!,
    cita.paciente.celular,
  ].join('\n');
  // Desplazable y con alto máximo: en celulares chicos las 7 acciones no caben enteras (antes: «overflowed»).
  final eleccion = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (hoja) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                cita.paciente.nombre,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(detalle),
            ),
            const Divider(height: 1),
            if (cita.porAprobar)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Confirmar y avisar por WhatsApp'),
                onTap: () => Navigator.pop(hoja, 'confirmar'),
              ),
            if (cita.porAprobar)
              ListTile(
                leading: const Icon(Icons.do_not_disturb_on_outlined),
                title: const Text('Rechazar'),
                onTap: () => Navigator.pop(hoja, 'rechazar'),
              ),
            if (cita.programada && !cita.llego)
              ListTile(
                leading: const Icon(Icons.how_to_reg_outlined),
                title: const Text('Llegó'),
                subtitle: Text('Ya está en ${voc.elLocal}'),
                onTap: () => Navigator.pop(hoja, 'llego'),
              ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Escribir por WhatsApp'),
              onTap: () => Navigator.pop(hoja, 'whatsapp'),
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Llamar'),
              onTap: () => Navigator.pop(hoja, 'llamar'),
            ),
            if (puedeCambiar)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Mover a otra hora'),
                onTap: () => Navigator.pop(hoja, 'mover'),
              ),
            if (puedeCambiar)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancelar cita'),
                onTap: () => Navigator.pop(hoja, 'cancelar'),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;

  switch (eleccion) {
    case 'confirmar':
      await confirmarCita(context, ref, cita, alCambiar: alCambiar);
    case 'llego':
      final error = await ref
          .read(agendaProvider.notifier)
          .accion(AccionConsulta.llego, cita.id);
      if (error != null && context.mounted) avisar(context, error);
      alCambiar?.call();
    case 'rechazar':
      await ejecutarDecision(
        context,
        ref,
        cita.id,
        'rechazar',
        'Reserva rechazada',
        alCambiar: alCambiar,
      );
    case 'whatsapp':
      await abrirWhatsapp(
        context,
        'https://wa.me/${cita.paciente.celular.replaceAll('+', '')}',
      );
    case 'llamar':
      await launchUrl(Uri.parse('tel:${cita.paciente.celular}'));
    case 'mover':
      final inicio = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Elige la nueva hora')),
            body: Builder(
              builder: (pantalla) => SelectorHora(
                consulta: (
                  tratamientoId: cita.tratamiento.id,
                  excluirCita: cita.id,
                  profesionalId: null, // al mover, el servidor usa el profesional de la cita
                ),
                alElegir: (hora) => Navigator.of(pantalla).pop(hora),
              ),
            ),
          ),
        ),
      );
      if (inicio != null && context.mounted) {
        await _ejecutar(
          context,
          ref,
          '/citas/${cita.id}/reprogramar',
          {'inicio': inicio},
          'Cita movida',
          alCambiar,
        );
      }
    case 'cancelar':
      final ok = await confirmar(
        context,
        '¿Cancelar la cita de ${cita.paciente.nombre}?',
        'El horario quedará libre para otros ${voc.clientes}.',
        accion: 'Cancelar cita',
      );
      if (ok && context.mounted) {
        await _ejecutar(
          context,
          ref,
          '/citas/${cita.id}/cancelar',
          null,
          'Cita cancelada',
          alCambiar,
        );
      }
  }
}

/// «Confirmar y avisar». Si el cliente ofreció otro precio, primero se acepta o se pone el precio final.
Future<void> confirmarCita(
  BuildContext context,
  WidgetRef ref,
  Cita cita, {
  VoidCallback? alCambiar,
}) async {
  Map<String, dynamic>? cuerpo;
  if (cita.tieneOferta) {
    final precio = await elegirPrecio(context, cita);
    if (precio == null || !context.mounted) return;
    cuerpo = {'precio_acordado': precio};
  }
  await _ejecutar(
    context,
    ref,
    '/citas/${cita.id}/aprobar',
    cuerpo,
    'Cita confirmada',
    alCambiar,
    directo: true,
  );
}

/// Devuelve el precio en soles, o null si se canceló.
Future<double?> elegirPrecio(BuildContext context, Cita cita) async {
  final ofrecido = cita.precioOfrecido!;
  final referencia = cita.precioReferencia;
  final eleccion = await showDialog<Object>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('${cita.paciente.nombre} ofrece ${soles(ofrecido)}'),
      content: Text(
        referencia == null
            ? 'Acepta la oferta o pon el precio final. Ese precio irá en el mensaje de confirmación.'
            : 'Tu precio de referencia es ${soles(referencia)}. Acepta la oferta o pon el precio final; '
                  'ese precio irá en el mensaje de confirmación.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo, 'otro'),
          child: const Text('Poner otro precio'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogo, ofrecido),
          child: Text('Aceptar ${soles(ofrecido)}'),
        ),
      ],
    ),
  );
  if (eleccion is int) return eleccion / 100;
  if (eleccion != 'otro' || !context.mounted) return null;
  return _precioManual(context, referencia ?? ofrecido);
}

Future<double?> _precioManual(BuildContext context, int sugerido) {
  final campo = TextEditingController(
    text: (sugerido / 100).toStringAsFixed(sugerido % 100 == 0 ? 0 : 2),
  );
  return showDialog<double>(
    context: context,
    builder: (dialogo) {
      void listo() {
        final valor = double.tryParse(campo.text.replaceAll(',', '.'));
        if (valor != null && valor > 0) Navigator.pop(dialogo, valor);
      }

      return AlertDialog(
        title: const Text('Precio final'),
        content: TextField(
          key: const Key('precio-final'),
          controller: campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(prefixText: 'S/ '),
          onSubmitted: (_) => listo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: listo, child: const Text('Confirmar')),
        ],
      );
    },
  );
}

Future<void> ejecutarDecision(
  BuildContext context,
  WidgetRef ref,
  int citaId,
  String accion,
  String titulo, {
  VoidCallback? alCambiar,
  bool directo = false,
}) => _ejecutar(
  context,
  ref,
  '/citas/$citaId/$accion',
  null,
  titulo,
  alCambiar,
  directo: directo,
);

List<Siguiente> siguientesDe(Map<String, dynamic> datos) => [
  for (final s in (datos['siguientes'] as List? ?? const []))
    Siguiente.fromJson(s as Map<String, dynamic>),
];

Future<void> _ejecutar(
  BuildContext context,
  WidgetRef ref,
  String ruta,
  Map<String, dynamic>? cuerpo,
  String titulo,
  VoidCallback? alCambiar, {
  bool directo = false,
}) async {
  try {
    final datos = await ref.read(apiProvider).post(ruta, cuerpo);
    ref
        .read(agendaProvider.notifier)
        .aplicarAgenda(datos['agenda'] as Map<String, dynamic>);
    alCambiar?.call();
    if (!context.mounted) return;
    final url = datos['whatsapp_url'] as String?;
    if (directo && url != null) return abrirWhatsapp(context, url);
    await ofrecerAviso(context, titulo, url, siguientes: siguientesDe(datos));
  } on ApiError catch (e) {
    if (context.mounted) avisar(context, e.mensaje);
  }
}
