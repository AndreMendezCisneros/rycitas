import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/fechas.dart';
import '../../shared/comunes.dart';
import 'datos_cliente.dart';

class AvisoSuave extends StatelessWidget {
  const AvisoSuave({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Icon(icono, size: 48, color: esquema.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String? urlMedia(Object? ruta) {
  if (ruta is! String || ruta.isEmpty) return null;
  return ruta.startsWith('http') ? ruta : '$apiUrl$ruta';
}

class FotoNegocio extends StatelessWidget {
  const FotoNegocio({super.key, required this.negocio, this.lado = 52});

  final Json negocio;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final url = urlMedia(negocio['foto']);
    final esquema = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(lado / 3.2),
      child: SizedBox.square(
        dimension: lado,
        child: url == null
            ? ColoredBox(
                color: esquema.primaryContainer,
                child: Center(
                  child: Text(
                    (negocio['nombre'] as String).characters.first.toUpperCase(),
                    style: TextStyle(
                      fontSize: lado / 2.4,
                      fontWeight: FontWeight.w700,
                      color: esquema.onPrimaryContainer,
                    ),
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: esquema.primaryContainer),
              ),
      ),
    );
  }
}

/// Un lugar en la lista. Con [conProgreso] muestra los sellos y el nivel del cliente ahí.
class TarjetaNegocio extends StatelessWidget {
  const TarjetaNegocio({super.key, required this.negocio, this.conProgreso = false});

  final Json negocio;
  final bool conProgreso;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final sellos = negocio['sellos'] as int? ?? 0;
    final meta = negocio['meta'] as int? ?? 0;
    final cupones = negocio['cupones'] as int? ?? 0;
    return Card(
      key: Key('negocio-${negocio['slug']}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/cliente/negocio/${negocio['slug']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              FotoNegocio(negocio: negocio),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(negocio['nombre'] as String, style: textos.titleMedium),
                    Text(
                      '${negocio['rubro_nombre']} · ${negocio['direccion']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: esquema.onSurfaceVariant),
                    ),
                    if (conProgreso) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Pastilla(icono: Icons.workspace_premium_rounded, texto: negocio['nivel'] as String? ?? ''),
                          if (negocio['fidelidad'] == true && meta > 0)
                            _Pastilla(icono: Icons.verified_rounded, texto: '$sellos/$meta sellos'),
                          if (cupones > 0)
                            _Pastilla(
                              icono: Icons.local_offer_rounded,
                              texto: '$cupones cupón${cupones > 1 ? 'es' : ''}',
                              resaltado: true,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.icono, required this.texto, this.resaltado = false});

  final IconData icono;
  final String texto;
  final bool resaltado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = resaltado ? esquema.tertiaryContainer : esquema.surfaceContainerHighest;
    final color = resaltado ? esquema.onTertiaryContainer : esquema.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de sellos: un círculo por sello, el último es el premio.
class TarjetaSellos extends StatelessWidget {
  const TarjetaSellos({super.key, required this.tarjeta, this.negocio});

  final Json tarjeta;
  final String? negocio;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final sellos = tarjeta['sellos'] as int;
    final meta = tarjeta['meta'] as int;
    final nivel = tarjeta['nivel'] as Json;
    final lista = tarjeta['lista'] == true;
    return Card(
      key: const Key('tarjeta-sellos'),
      color: esquema.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    negocio ?? 'Tu tarjeta de sellos',
                    style: textos.titleMedium?.copyWith(color: esquema.onPrimaryContainer),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text('Nivel ${nivel['nombre']}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < meta; i++)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < sellos ? esquema.primary : esquema.surface.withValues(alpha: 0.7),
                      border: Border.all(color: esquema.primary.withValues(alpha: 0.5)),
                    ),
                    child: Icon(
                      i == meta - 1 ? Icons.card_giftcard_rounded : Icons.check_rounded,
                      size: 20,
                      color: i < sellos ? esquema.onPrimary : esquema.primary.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lista
                  ? '¡Tarjeta llena! Pide tu premio en tu próxima visita: ${tarjeta['premio']}.'
                  : 'Te faltan ${meta - sellos} para: ${tarjeta['premio']}.',
              style: textos.bodyMedium?.copyWith(color: esquema.onPrimaryContainer, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              [
                'Ganas un sello por cada visita',
                if (tarjeta['puntualidad'] == true) 'y otro si llegas a tiempo',
              ].join(' '),
              style: textos.bodySmall?.copyWith(color: esquema.onPrimaryContainer),
            ),
            if (nivel['siguiente'] != null)
              Text(
                'Con ${nivel['faltan']} visita${nivel['faltan'] == 1 ? '' : 's'} más (en 6 meses) llegas a ${nivel['siguiente']}.',
                style: textos.bodySmall?.copyWith(color: esquema.onPrimaryContainer),
              ),
          ],
        ),
      ),
    );
  }
}

class TarjetaCupon extends StatelessWidget {
  const TarjetaCupon({super.key, required this.cupon, this.negocio, this.alUsar});

  final Json cupon;
  final String? negocio;
  final VoidCallback? alUsar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      key: Key('cupon-${cupon['codigo']}'),
      color: esquema.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.local_offer_rounded, color: esquema.onTertiaryContainer),
        title: Text(cupon['titulo'] as String, style: TextStyle(color: esquema.onTertiaryContainer)),
        subtitle: Text(
          [
            ?negocio,
            if (cupon['servicio'] != null) 'Solo ${cupon['servicio']}',
            'Vence el ${Fechas.diaCorto(cupon['vence_el'] as String)}',
          ].join(' · '),
          style: TextStyle(color: esquema.onTertiaryContainer),
        ),
        trailing: alUsar == null
            ? Text(cupon['descuento'] as String, style: Theme.of(context).textTheme.titleMedium)
            : FilledButton.tonal(onPressed: alUsar, child: const Text('Usar')),
      ),
    );
  }
}

/// Código para invitar amigos: un sello para cada uno cuando el amigo termina su primera cita.
class TarjetaInvitar extends StatelessWidget {
  const TarjetaInvitar({super.key, required this.codigo, this.invitados = 0});

  final String codigo;
  final int invitados;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final mensaje =
        'Te invito a RyCitas para reservar sin llamar. Al registrarte usa mi código $codigo y los dos ganamos un sello.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invita a un amigo', style: textos.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cuando termine su primera cita, los dos ganan un sello.'
              '${invitados > 0 ? ' Ya invitaste a $invitados.' : ''}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    codigo,
                    key: const Key('codigo-referido'),
                    style: textos.headlineSmall?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    avisar(context, 'Código copiado');
                  },
                ),
                FilledButton.icon(
                  onPressed: () => abrirWhatsapp(context, 'https://wa.me/?text=${Uri.encodeComponent(mensaje)}'),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> abrirEnlace(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) avisar(context, 'No se pudo abrir el enlace.');
}
