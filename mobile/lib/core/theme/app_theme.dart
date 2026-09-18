import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Ensambla el `ThemeData` claro de OptiRuta a partir de los tokens.
///
/// No hay tema oscuro en el MVP. Ningún feature define colores, paddings ni
/// estilos inline: todo sale de aquí y de `core/widgets`.
abstract final class AppTheme {
  static ThemeData get light {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.brandRed,
      onSecondary: AppColors.onBrandRed,
      tertiary: AppColors.navy,
      onTertiary: AppColors.onNavy,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.card,
      onSurface: AppColors.textBody,
    );

    final TextTheme textTheme = const TextTheme(
      displaySmall: AppTypography.display,
      titleLarge: AppTypography.title,
      titleMedium: AppTypography.subtitle,
      bodyMedium: AppTypography.body,
      labelMedium: AppTypography.label,
      bodySmall: AppTypography.caption,
    ).apply(fontFamily: AppTypography.family);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppTypography.family,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      dividerColor: AppColors.dividerTable,
      iconTheme: const IconThemeData(color: AppColors.slate, size: 24),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brandRed,
        selectionColor: AppColors.brandRedTint,
        selectionHandleColor: AppColors.brandRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: _inputDecorationTheme,
    );
  }

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: AppTypography.family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        isDense: false,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        prefixIconColor: AppColors.slate,
        suffixIconColor: AppColors.textSecondary,
        labelStyle: _labelStyle,
        floatingLabelStyle: _labelStyle,
        hintStyle: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textDisabled,
        ),
        // El texto de error visible lo dibujan AppTextField / la checklist;
        // aquí se colapsa para conservar el borde rojo y la semántica sin
        // duplicar el mensaje.
        errorStyle: TextStyle(
          fontSize: 0.01,
          height: 0.01,
          color: Color(0x00000000),
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.borderInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.borderInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.brandRed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      );
}
