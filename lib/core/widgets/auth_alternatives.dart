import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Separador "o continúa con" entre el botón primario y los accesos alternos.
class OrDivider extends StatelessWidget {
  const OrDivider({this.label = 'o continúa con', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: AppColors.borderCard, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderCard, height: 1)),
      ],
    );
  }
}

/// Botón "Continuar con Google". Con [onPressed] nulo se muestra deshabilitado
/// (p. ej. mientras otra operación de login está en curso).
class GoogleButton extends StatelessWidget {
  const GoogleButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textBody,
            disabledForegroundColor: AppColors.textBody,
            backgroundColor: AppColors.card,
            side: const BorderSide(color: AppColors.borderInput),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
            textStyle: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/branding/google_g.png',
                width: 20,
                height: 20,
                filterQuality: FilterQuality.medium,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) =>
                        const Icon(
                          Icons.g_mobiledata,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
              ),
              const SizedBox(width: AppSpacing.x2),
              const Text('Continuar con Google'),
            ],
          ),
        ),
      ),
    );
  }
}
