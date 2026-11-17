import 'package:flutter/material.dart';

import '../shared/diseno/paleta.dart';

/// Frambuesa de RyCitas. El color propio del negocio ya no tiñe la app: es solo un acento en su ficha.
const colorMarca = Paleta.frambuesa;
const colorAviso = Paleta.ambarFondo;
const colorAvisoTexto = Paleta.ambarTexto;
const colorExito = Paleta.verde;
const fuente = 'Jakarta';

/// Colores de estado de una cita, iguales en toda la app. «No vino» va en gris (con tachado donde se lista):
/// el rojo es de la marca y confundiría.
class ColoresEstado {
  static Color de(String estado, ColorScheme esquema) => switch (estado) {
    'por_aprobar' || 'pendiente' => Paleta.ambar,
    'programada' => Paleta.frambuesa,
    'en_curso' => Paleta.verde,
    'terminada' => Paleta.gris,
    'no_asistio' => const Color(0xFF6B5A62),
    _ => esquema.outline,
  };
}

/// Diseño «blanco y frambuesa»: fondo blanco, tarjetas de 24 px con sombra rosada, tipografía Plus Jakarta Sans y
/// botones de 52 px (la app se usa con una mano, entre cliente y cliente). Siempre claro: es parte de la marca.
ThemeData temaRyCitas() {
  const brillo = Brightness.light;
  final esquema = ColorScheme.fromSeed(
    seedColor: Paleta.frambuesa,
    brightness: brillo,
    primary: Paleta.frambuesa,
    secondary: Paleta.rojo,
    surface: Paleta.fondo,
    onSurface: Paleta.texto,
  ).copyWith(
    primaryContainer: Paleta.rosa,
    onPrimaryContainer: Paleta.frambuesaOscura,
    onSurfaceVariant: Paleta.textoSuave,
    outlineVariant: Paleta.borde,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Paleta.superficie,
    surfaceContainer: Paleta.rosaClaro,
    surfaceContainerHigh: Paleta.rosaClaro,
    surfaceContainerHighest: Paleta.rosa,
  );
  const altoBoton = Size(64, 52);
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  const textoBoton = TextStyle(fontFamily: fuente, fontSize: 16, fontWeight: FontWeight.w700);
  final base = ThemeData(useMaterial3: true, colorScheme: esquema, fontFamily: fuente, brightness: brillo);
  final textos = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
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
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Paleta.frambuesa.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Paleta.borde),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: esquema.primary.withValues(alpha: 0.14),
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
      fillColor: Paleta.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
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
      shape: const StadiumBorder(),
      side: BorderSide(color: esquema.outlineVariant),
      backgroundColor: Colors.white,
      selectedColor: Paleta.rosa,
      checkmarkColor: Paleta.frambuesa,
      labelStyle: const TextStyle(fontFamily: fuente, fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Paleta.borde,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Paleta.texto,
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
