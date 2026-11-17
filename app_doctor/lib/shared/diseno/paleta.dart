import 'package:flutter/material.dart';

/// Paleta de RyCitas: blanco con rojo y frambuesa. Contraste comprobado sobre blanco (WCAG AA):
/// - [frambuesa] ~6:1: texto, botones y todo lo que se lee.
/// - [rojo] ~4:1: solo íconos, acentos, degradados y texto grande; nunca texto pequeño.
abstract final class Paleta {
  static const frambuesa = Color(0xFFC2185B);
  static const frambuesaOscura = Color(0xFF8E0E43);
  static const rojo = Color(0xFFE53950);
  static const coral = Color(0xFFFF7A85);
  static const rosa = Color(0xFFFCE4EC);
  static const rosaClaro = Color(0xFFFFF4F7);

  static const fondo = Color(0xFFFFFFFF);
  static const superficie = Color(0xFFFFF8FA);
  static const borde = Color(0xFFF3DDE5);

  /// Neutros cálidos (no grises fríos): el texto combina con la frambuesa.
  static const texto = Color(0xFF2A1A22);
  static const textoSuave = Color(0xFF7A6470);

  static const ambar = Color(0xFFE59A0B);
  static const ambarFondo = Color(0xFFFFF4DB);
  static const ambarTexto = Color(0xFF7A5200);
  static const verde = Color(0xFF16A34A);
  static const verdeFondo = Color(0xFFE7F7EC);
  static const gris = Color(0xFF9A8A92);

  static const degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [frambuesa, rojo],
  );

  static const degradadoSuave = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rosa, rosaClaro, fondo],
  );

  /// Sombra suave teñida de frambuesa: las tarjetas «flotan» sin verse sucias.
  static List<BoxShadow> sombra([double fuerza = 1]) => [
    BoxShadow(
      color: frambuesa.withValues(alpha: 0.08 * fuerza),
      blurRadius: 24 * fuerza,
      offset: Offset(0, 8 * fuerza),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03 * fuerza),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
}
