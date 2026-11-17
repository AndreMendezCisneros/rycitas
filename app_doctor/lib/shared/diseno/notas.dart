import 'package:flutter/material.dart';

import 'tonos.dart';

/// Ideas para las notas de una reserva, según el rubro: ayudan a escribir sin frenar la reserva.
List<String> sugerenciasDeNotas(String rubro) => switch (rubro) {
  'peluqueria' => ['Traigo foto de referencia', 'Corte en capas', 'Retoque de raíz', 'Cabello largo', 'Primera vez'],
  'barberia' => ['Degradado bajo', 'Perfilado de barba', 'Traigo foto de referencia', 'Primera vez'],
  'estetica' => ['Piel sensible', 'Tengo alergias', 'Es para un evento', 'Diseño de cejas', 'Primera vez'],
  'odontologia' || 'salud' => ['Tengo dolor', 'Es control', 'Tomo medicamentos', 'Primera vez'],
  'veterinaria' => ['Es nervioso', 'Vacunas', 'Baño y corte', 'Primera visita'],
  _ => ['Primera vez', 'Llego con el tiempo justo', 'Prefiero que me llamen'],
};

/// Campo de notas con sugerencias tocables: cada chip suma su frase al texto.
class CampoNotas extends StatelessWidget {
  const CampoNotas({super.key, required this.controlador, required this.rubro, this.etiqueta});

  final TextEditingController controlador;
  final String rubro;
  final String? etiqueta;

  void _agregar(String frase) {
    final actual = controlador.text.trim();
    if (actual.toLowerCase().contains(frase.toLowerCase())) return;
    controlador.text = actual.isEmpty ? frase : '$actual. $frase';
    controlador.selection = TextSelection.collapsed(offset: controlador.text.length);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('campo-notas'),
        controller: controlador,
        maxLength: 500,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: etiqueta ?? '¿Algo que debamos saber? (opcional)',
          alignLabelWithHint: true,
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Icon(Icons.sticky_note_2_outlined, color: context.tonos.acento),
          ),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final s in sugerenciasDeNotas(rubro))
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16, color: context.tonos.acento),
              label: Text(s),
              onPressed: () => _agregar(s),
            ),
        ],
      ),
    ],
  );
}

/// La nota del cliente, destacada (para que el negocio la vea de un vistazo).
class NotaCita extends StatelessWidget {
  const NotaCita(this.texto, {super.key, this.compacta = false});

  final String texto;
  final bool compacta;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: compacta ? 6 : 10),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: compacta ? 6 : 10),
    decoration: BoxDecoration(
      color: context.tonos.rosaClaro,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.tonos.rosa),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.sticky_note_2_rounded, size: 16, color: context.tonos.acento),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            maxLines: compacta ? 2 : null,
            overflow: compacta ? TextOverflow.ellipsis : null,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tonos.texto, height: 1.35),
          ),
        ),
      ],
    ),
  );
}
