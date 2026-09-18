import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Escala tipográfica acotada. Una sola familia: Inter.
///
/// Pesos permitidos: SemiBold/Bold (títulos), Medium (labels/subtítulos),
/// Regular (contenido y formularios). No usar otros tamaños ni pesos.
abstract final class AppTypography {
  static const String family = 'Inter';

  /// Cifras tabulares para cantidades, costos, distancias y porcentajes.
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textBody,
  );

  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textBody,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}
