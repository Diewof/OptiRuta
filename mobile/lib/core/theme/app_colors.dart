import 'package:flutter/painting.dart';

/// Paleta cerrada de OptiRuta, derivada del logo (azul oscuro, rojo oscuro,
/// gris, blanco). Fuente única de verdad para color.
///
/// Los neutros de texto/borde están pre-aplanados sobre blanco a partir de la
/// opacidad del gris pizarra (ver `Documentacion/Esquemas/sistema-de-diseno.md`,
/// sección 1).
abstract final class AppColors {
  // Principales — dominan la UI.
  static const Color navy = Color(0xFF14273F); // azul marino (logo)
  static const Color slate = Color(0xFF333A45); // gris pizarra (logo)
  static const Color canvas = Color(0xFFF3F4F6); // fondo de pantalla
  static const Color card = Color(0xFFFFFFFF); // fondo de tarjetas/formularios

  /// Azul de acción: única acción principal por pantalla (botón primario).
  static const Color primary = Color(0xFF1E3A5F);

  /// Rojo de marca: acento de identidad (logo, franja, foco, destructivo).
  /// Nunca como fondo de pantalla ni relleno decorativo.
  static const Color brandRed = Color(0xFFA62C2C);

  // Estados — solo badges, bordes, iconos y texto de estado.
  static const Color success = Color(0xFF2E7D52);
  static const Color warning = Color(0xFFC6871B);
  static const Color error = Color(0xFFC43D2E);

  // Neutros derivados (opacidad de #333A45 sobre blanco).
  static const Color textPrimary = Color(0xFF14273F);
  static const Color textBody = Color(0xFF333A45);
  static const Color textSecondary = Color(0xFF5C6470);
  static const Color textDisabled = Color(0xFF9AA0A9);
  static const Color borderInput = Color(0xFFB4B8BF);
  static const Color borderCard = Color(0xFFD9DBDF);
  static const Color dividerTable = Color(0xFFE6E7EA);

  // Texto sobre superficies llenas.
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onNavy = Color(0xFFFFFFFF);
  static const Color onBrandRed = Color(0xFFFFFFFF);

  // Overlay "pressed" para superficies de acción (#14273F @ 20%).
  static const Color pressedOverlay = Color(0x3314273F);

  // Tintes derivados por mezcla con blanco (no son colores nuevos de marca).
  static const Color navyTint = Color(0xFFEDEFF3); // navy @ ~6 %
  static const Color navyTint12 = Color(
    0xFFE3E5E8,
  ); // navy @ ~12 %: hilo, esqueleto
  static const Color brandRedTint = Color(0xFFF6E9E9); // brandRed @ ~10 %
  static const Color successTint = Color(0xFFE7F1EC);
  static const Color warningTint = Color(0xFFFBF1DC);
  static const Color errorTint = Color(0xFFF8E9E7);
}
