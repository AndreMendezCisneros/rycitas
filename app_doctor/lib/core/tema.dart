import 'package:flutter/material.dart';

/// Índigo de RyCitas: el de la marca cuando el negocio no tiene color propio.
const colorMarca = Color(0xFF4F46E5);
const colorAviso = Color(0xFFFFF4DB);
const colorAvisoTexto = Color(0xFF7A5200);
const colorExito = Color(0xFF16A34A);
const fuente = 'Jakarta';

/// Colores de estado de una cita, iguales en toda la app.
class ColoresEstado {
  static Color de(String estado, ColorScheme esquema) => switch (estado) {
    'por_aprobar' => const Color(0xFFF59E0B),
    'pendiente' => const Color(0xFFF59E0B),
    'programada' => esquema.primary,
    'en_curso' => colorExito,
    'terminada' => const Color(0xFF94A3B8),
    'no_asistio' => const Color(0xFFEF4444),
    _ => esquema.outline,
  };
}

/// Diseño «moderno claro»: superficies limpias, tarjetas de 20 px sin bordes duros, tipografía Plus Jakarta Sans y
/// botones de 52 px (la app se usa con una mano, entre cliente y cliente). [color] es el del negocio.
ThemeData temaRyCitas([Color? color, Brightness brillo = Brightness.light]) {
  final oscuro = brillo == Brightness.dark;
  final principal = color ?? colorMarca;
  final esquema = ColorScheme.fromSeed(
    seedColor: principal,
    brightness: brillo,
    primary: oscuro ? null : principal,
    surface: oscuro ? const Color(0xFF111318) : const Color(0xFFF6F7FB),
  ).copyWith(
    surfaceContainerLowest: oscuro ? const Color(0xFF181B22) : Colors.white,
    surfaceContainerLow: oscuro ? const Color(0xFF1C1F27) : Colors.white,
  );
  const altoBoton = Size(64, 52);
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const textoBoton = TextStyle(fontFamily: fuente, fontSize: 16, fontWeight: FontWeight.w700);
  final base = ThemeData(useMaterial3: true, colorScheme: esquema, fontFamily: fuente, brightness: brillo);
  final textos = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
  return base.copyWith(
    textTheme: textos,
    scaffoldBackgroundColor: esquema.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textos.titleLarge?.copyWith(color: esquema.onSurface, fontFamily: fuente),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: altoBoton, shape: forma, textStyle: textoBoton, elevation: 0),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: altoBoton,
        shape: forma,
        textStyle: textoBoton,
        side: BorderSide(color: esquema.outlineVariant, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: textoBoton, shape: forma)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      extendedTextStyle: textoBoton,
    ),
    cardTheme: CardThemeData(
      color: esquema.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: esquema.primary.withValues(alpha: oscuro ? 0.3 : 0.14),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fuente,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? esquema.primary : esquema.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? esquema.primary : esquema.onSurfaceVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: esquema.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: esquema.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: esquema.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: esquema.outlineVariant),
      labelStyle: const TextStyle(fontFamily: fuente, fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: esquema.outlineVariant.withValues(alpha: 0.6), space: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: fuente, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
