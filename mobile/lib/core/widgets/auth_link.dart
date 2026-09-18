import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Enlace de navegación dentro de las pantallas de autenticación.
///
/// Azul de acción (`#1E3A5F`, 11.5:1 sobre blanco) con subrayado.
/// Touch target de 48 dp de alto.
class AuthLink extends StatelessWidget {
  const AuthLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        overlayColor: AppColors.pressedOverlay,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(label),
    );
  }
}

/// Fila "pregunta + enlace" usada al pie de cada pantalla de autenticación.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    required this.question,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String question;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          question,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        AuthLink(label: actionLabel, onPressed: onPressed),
      ],
    );
  }
}
