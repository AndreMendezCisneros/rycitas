import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/fechas.dart';
import '../core/negocio.dart';
import '../core/tema.dart';
import 'modelos.dart';

void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Abre el WhatsApp del doctor con el mensaje ya escrito (RF-30): no cuesta nada.
Future<void> abrirWhatsapp(BuildContext context, String url) async {
  final abierto = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!abierto && context.mounted) avisar(context, 'No se pudo abrir WhatsApp.');
}

/// Después de cambiar una cita, ofrece avisar al paciente con un toque. Si quedó un espacio libre,
/// también ofrece avisar a los siguientes pacientes del día por si pueden venir antes.
Future<void> ofrecerAviso(
  BuildContext context,
  String titulo,
  String? url, {
  List<Siguiente> siguientes = const [],
}) async {
  if (siguientes.isNotEmpty) return _avisosTrasHueco(context, titulo, url, siguientes);
  if (url == null) return;
  final avisarAhora = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text(titulo),
      content: Text('¿Quieres avisarle al ${vocDe(context).cliente} por WhatsApp? El mensaje ya está escrito.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Avisar')),
      ],
    ),
  );
  if (avisarAhora == true && context.mounted) await abrirWhatsapp(context, url);
}

Future<void> _avisosTrasHueco(BuildContext context, String titulo, String? url, List<Siguiente> siguientes) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (hoja) => SafeArea(
      child: _ListaAvisos(titulo: titulo, url: url, siguientes: siguientes),
    ),
  );
}

/// Queda abierta al volver de WhatsApp, para avisar a varios pacientes seguidos.
class _ListaAvisos extends StatefulWidget {
  const _ListaAvisos({required this.titulo, required this.url, required this.siguientes});

  final String titulo;
  final String? url;
  final List<Siguiente> siguientes;

  @override
  State<_ListaAvisos> createState() => _ListaAvisosState();
}

class _ListaAvisosState extends State<_ListaAvisos> {
  final _avisados = <String>{};

  Future<void> _abrir(String clave, String url) async {
    setState(() => _avisados.add(clave));
    await abrirWhatsapp(context, url);
  }

  Widget _boton(String clave, String url, String texto) {
    if (_avisados.contains(clave)) {
      return OutlinedButton.icon(
        onPressed: () => _abrir(clave, url),
        icon: const Icon(Icons.check),
        label: const Text('Enviado'),
      );
    }
    return FilledButton.icon(onPressed: () => _abrir(clave, url), icon: const Icon(Icons.chat), label: Text(texto));
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.titulo, style: textos.titleLarge),
        const SizedBox(height: 12),
        if (widget.url != null) ...[
          Text('Avisa al ${vocDe(context).cliente}. El mensaje ya está escrito.'),
          const SizedBox(height: 8),
          _boton('cancelado', widget.url!, 'Avisar al ${vocDe(context).cliente}'),
          const Divider(height: 32),
        ],
        Text('Quedó un espacio libre', style: textos.titleMedium),
        Text(
          'Pregunta a los siguientes ${vocDe(context).clientes} de ese día si pueden venir antes. Si alguno acepta, usa «Mover».',
        ),
        for (final s in widget.siguientes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.paciente),
            subtitle: Text('Su cita: ${Fechas.hora(s.inicio)}'),
            trailing: _boton('${s.citaId}', s.whatsappUrl, 'Avisar'),
          ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
      ],
    );
  }
}

/// «Me demoro»: elige cuánto (5 a 30 min). Devuelve null si se cierra sin elegir.
Future<int?> elegirDemora(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (hoja) {
      final textos = Theme.of(hoja).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('¿Cuánto te vas a demorar?', style: textos.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Se corre la hora estimada de los que esperan y te damos sus mensajes listos para WhatsApp.',
                  style: textos.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in const [5, 10, 15, 20, 30])
                      ActionChip(
                        key: Key('demora-$m'),
                        label: Text('+$m min'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        onPressed: () => Navigator.pop(hoja, m),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(hoja), child: const Text('Cancelar')),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Tras «Me demoro»: a quién avisar, cada uno con su nueva hora y su WhatsApp listo.
Future<void> mostrarAvisosDemora(BuildContext context, int minutos, List<AvisoDemora> avisos) async {
  if (avisos.isEmpty) {
    return avisar(context, 'Listo: +$minutos min. Nadie más espera, no hace falta avisar.');
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (hoja) => SafeArea(
      child: _ListaDemora(minutos: minutos, avisos: avisos),
    ),
  );
}

class _ListaDemora extends StatefulWidget {
  const _ListaDemora({required this.minutos, required this.avisos});

  final int minutos;
  final List<AvisoDemora> avisos;

  @override
  State<_ListaDemora> createState() => _ListaDemoraState();
}

class _ListaDemoraState extends State<_ListaDemora> {
  final _avisados = <int>{};

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        Text('Avisa que vas con retraso', style: textos.titleLarge),
        const SizedBox(height: 4),
        Text('Pídeles que te esperen. El mensaje ya lleva su nueva hora y su enlace para verla.'),
        const SizedBox(height: 8),
        for (final a in widget.avisos)
          ListTile(
            key: Key('aviso-demora-${a.citaId}'),
            contentPadding: EdgeInsets.zero,
            title: Text(a.paciente),
            subtitle: Text('${Fechas.hora(a.inicio)} → ${Fechas.hora(a.inicioEstimado)} (+${a.retrasoMin} min)'),
            trailing: _avisados.contains(a.citaId)
                ? OutlinedButton.icon(
                    onPressed: () => abrirWhatsapp(context, a.whatsappUrl),
                    icon: const Icon(Icons.check),
                    label: const Text('Enviado'),
                  )
                : FilledButton.icon(
                    onPressed: () async {
                      setState(() => _avisados.add(a.citaId));
                      await abrirWhatsapp(context, a.whatsappUrl);
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Avisar'),
                  ),
          ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
      ],
    );
  }
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String accion = 'Sí'}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Volver')),
        FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: Text(accion)),
      ],
    ),
  );
  return respuesta == true;
}

class ErrorConReintento extends StatelessWidget {
  const ErrorConReintento({super.key, required this.error, required this.alReintentar});

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final mensaje = error is ApiError ? (error as ApiError).mensaje : 'Algo salió mal.';
    final esquema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: esquema.errorContainer,
              child: Icon(Icons.wifi_off_rounded, color: esquema.onErrorContainer, size: 30),
            ),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(strokeCap: StrokeCap.round));
}

/// Estado vacío con ícono: dice qué pasa y no deja la pantalla en blanco.
class Vacio extends StatelessWidget {
  const Vacio(this.texto, {super.key, this.icono = Icons.event_available_rounded});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: esquema.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icono, size: 34, color: esquema.primary),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Círculo con las iniciales: «Rosa Paz» da «RP». El color sale del nombre, siempre el mismo para la misma persona.
class Avatar extends StatelessWidget {
  const Avatar(this.nombre, {super.key, this.radio = 22});

  final String nombre;
  final double radio;

  static const _tonos = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF97316),
  ];

  String get _iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && !p.endsWith('.')).toList();
    if (partes.isEmpty) return '?';
    return partes.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final tono = _tonos[nombre.codeUnits.fold<int>(0, (a, b) => a + b) % _tonos.length];
    return CircleAvatar(
      radius: radio,
      backgroundColor: tono.withValues(alpha: 0.16),
      child: Text(
        _iniciales,
        style: TextStyle(color: tono, fontWeight: FontWeight.w800, fontSize: radio * 0.72),
      ),
    );
  }
}

/// Estado de la cita como pastilla de color.
class ChipEstado extends StatelessWidget {
  const ChipEstado({super.key, required this.estado, required this.texto});

  final String estado;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final color = ColoresEstado.de(estado, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(99)),
      child: Text(
        texto,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Un número grande con su etiqueta: «5 citas», «2 por confirmar».
class TarjetaDato extends StatelessWidget {
  const TarjetaDato({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.icono,
    this.color,
    this.alTocar,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color? color;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final tono = color ?? esquema.primary;
    return Card(
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: tono),
              const SizedBox(height: 10),
              Text(valor, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título de grupo dentro de una lista: «AJUSTES DE LA AGENDA».
class TituloGrupo extends StatelessWidget {
  const TituloGrupo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      texto.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
