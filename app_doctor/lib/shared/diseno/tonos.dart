import 'package:flutter/material.dart';

import 'paleta.dart';

/// Colores que cambian con el tema (claro/oscuro): fondos, superficies, bordes, textos y el acento legible.
/// Los de la marca que no cambian (degradado, rojo, coral) siguen en [Paleta].
///
/// Contraste revisado (WCAG AA, 4,5:1 para texto normal):
/// - claro: texto 15:1 y textoSuave 6,3:1 sobre blanco; acento 6:1.
/// - oscuro: texto 15:1 y textoSuave 8:1 sobre la superficie; acento 7:1.
@immutable
class Tonos extends ThemeExtension<Tonos> {
  const Tonos({
    required this.fondo,
    required this.superficie,
    required this.superficieSuave,
    required this.borde,
    required this.texto,
    required this.textoSuave,
    required this.acento,
    required this.acentoFuerte,
    required this.rosa,
    required this.rosaClaro,
    required this.ambarFondo,
    required this.ambarTexto,
    required this.verdeFondo,
    required this.vidrio,
    required this.manchas,
  });

  static const claro = Tonos(
    fondo: Color(0xFFFFFFFF),
    superficie: Color(0xFFFFFFFF),
    superficieSuave: Color(0xFFFFF8FA),
    borde: Color(0xFFF0D6E0),
    texto: Color(0xFF2A1A22),
    textoSuave: Color(0xFF66505B),
    acento: Paleta.frambuesa,
    acentoFuerte: Paleta.frambuesaOscura,
    rosa: Color(0xFFFCE4EC),
    rosaClaro: Color(0xFFFFF4F7),
    ambarFondo: Color(0xFFFFF4DB),
    ambarTexto: Color(0xFF6B4700),
    verdeFondo: Color(0xFFE7F7EC),
    vidrio: Color(0xF2FFFFFF),
    manchas: 1,
  );

  static const oscuro = Tonos(
    fondo: Color(0xFF140C10),
    superficie: Color(0xFF21161B),
    superficieSuave: Color(0xFF1B1216),
    borde: Color(0xFF3B2A32),
    texto: Color(0xFFF7ECF0),
    textoSuave: Color(0xFFC9B4BE),
    acento: Color(0xFFFF8FB8),
    acentoFuerte: Color(0xFFFFC2D8),
    rosa: Color(0xFF45192D),
    rosaClaro: Color(0xFF2B1720),
    ambarFondo: Color(0xFF3A2B0C),
    ambarTexto: Color(0xFFFFD27A),
    verdeFondo: Color(0xFF123222),
    vidrio: Color(0xF221161B),
    manchas: 0.45,
  );

  final Color fondo;
  final Color superficie;
  final Color superficieSuave;
  final Color borde;
  final Color texto;
  final Color textoSuave;

  /// Frambuesa legible sobre el fondo (más clara en oscuro): texto, íconos y bordes de acento.
  final Color acento;
  final Color acentoFuerte;

  /// Contenedores rosados (chips elegidos, fondos de íconos).
  final Color rosa;
  final Color rosaClaro;
  final Color ambarFondo;
  final Color ambarTexto;
  final Color verdeFondo;

  /// Superficie de las capas flotantes (barra, hojas): casi opaca, sin desenfoque (rápido en cualquier teléfono).
  final Color vidrio;

  /// Fuerza de las manchas de color del fondo.
  final double manchas;

  @override
  Tonos copyWith() => this;

  @override
  Tonos lerp(Tonos? otro, double t) {
    if (otro == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tonos(
      fondo: c(fondo, otro.fondo),
      superficie: c(superficie, otro.superficie),
      superficieSuave: c(superficieSuave, otro.superficieSuave),
      borde: c(borde, otro.borde),
      texto: c(texto, otro.texto),
      textoSuave: c(textoSuave, otro.textoSuave),
      acento: c(acento, otro.acento),
      acentoFuerte: c(acentoFuerte, otro.acentoFuerte),
      rosa: c(rosa, otro.rosa),
      rosaClaro: c(rosaClaro, otro.rosaClaro),
      ambarFondo: c(ambarFondo, otro.ambarFondo),
      ambarTexto: c(ambarTexto, otro.ambarTexto),
      verdeFondo: c(verdeFondo, otro.verdeFondo),
      vidrio: c(vidrio, otro.vidrio),
      manchas: manchas + (otro.manchas - manchas) * t,
    );
  }
}

extension TonosDelTema on BuildContext {
  Tonos get tonos => Theme.of(this).extension<Tonos>() ?? Tonos.claro;
  bool get oscuro => Theme.of(this).brightness == Brightness.dark;
}
