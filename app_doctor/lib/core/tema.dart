import 'package:flutter/material.dart';

import '../shared/diseno/paleta.dart';
import '../shared/diseno/tonos.dart';

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
    'programada' => esquema.primary,
    'en_curso' => Paleta.verde,
    'terminada' => Paleta.gris,
    'no_asistio' => const Color(0xFF6B5A62),
    _ => esquema.outline,
  };
}

/// Diseño «blanco y frambuesa» (o «noche y frambuesa» en oscuro): tarjetas de 24 px, tipografía Plus Jakarta Sans
/// y botones de 52 px (la app se usa con una mano, entre cliente y cliente).
ThemeData temaRyCitas([Brightness brillo = Brightness.light]) {
  final oscuro = brillo == Brightness.dark;
  final t = oscuro ? Tonos.oscuro : Tonos.claro;
  final esquema =
      ColorScheme.fromSeed(
        seedColor: Paleta.frambuesa,
        brightness: brillo,
        primary: t.acento,
        onPrimary: oscuro ? const Color(0xFF3B0A20) : Colors.white,
        secondary: Paleta.rojo,
        surface: t.fondo,
        onSurface: t.texto,
      ).copyWith(
        primaryContainer: t.rosa,
        onPrimaryContainer: t.acentoFuerte,
        onSurfaceVariant: t.textoSuave,
        outline: t.textoSuave,
        outlineVariant: t.borde,
        surfaceContainerLowest: t.superficie,
        surfaceContainerLow: t.superficieSuave,
        surfaceContainer: t.rosaClaro,
        surfaceContainerHigh: t.rosaClaro,
        surfaceContainerHighest: t.rosa,
        secondaryContainer: t.rosa,
        onSecondaryContainer: t.acentoFuerte,
        tertiaryContainer: t.ambarFondo,
        onTertiaryContainer: t.ambarTexto,
      );
  const altoBoton = Size(64, 52);
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  const textoBoton = TextStyle(fontFamily: fuente, fontSize: 16, fontWeight: FontWeight.w700);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: fuente,
    brightness: brillo,
    extensions: [t],
  );
  final textos = base.textTheme
      .apply(bodyColor: t.texto, displayColor: t.texto)
      .copyWith(
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
    // Íconos sueltos con el color del texto: nunca quedan claros sobre blanco ni oscuros sobre negro.
    iconTheme: IconThemeData(color: t.textoSuave),
    scaffoldBackgroundColor: esquema.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // Tamaño explícito: el estilo del tema aún no trae tamaño aquí y la barra caía a 14 px.
      titleTextStyle: TextStyle(
        fontFamily: fuente,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: esquema.onSurface,
      ),
      iconTheme: IconThemeData(color: t.texto),
      actionsIconTheme: IconThemeData(color: t.texto),
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
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: textoBoton, shape: forma),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      extendedTextStyle: textoBoton,
    ),
    cardTheme: CardThemeData(
      color: t.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Paleta.frambuesa.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: t.borde),
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
      fillColor: t.superficieSuave,
      labelStyle: TextStyle(color: t.textoSuave),
      hintStyle: TextStyle(color: t.textoSuave),
      prefixIconColor: t.textoSuave,
      suffixIconColor: t.textoSuave,
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
      backgroundColor: t.superficie,
      selectedColor: t.rosa,
      checkmarkColor: t.acento,
      labelStyle: TextStyle(fontFamily: fuente, fontWeight: FontWeight.w600, color: t.texto),
      secondaryLabelStyle: TextStyle(fontFamily: fuente, fontWeight: FontWeight.w700, color: t.acentoFuerte),
      iconTheme: IconThemeData(color: t.acento, size: 18),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.superficie,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: t.borde,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: esquema.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: oscuro ? const Color(0xFFF7ECF0) : Paleta.texto,
      contentTextStyle: TextStyle(fontFamily: fuente, color: oscuro ? Paleta.texto : Colors.white),
      actionTextColor: oscuro ? Paleta.frambuesa : const Color(0xFFFF8FB8),
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
