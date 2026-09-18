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

/// Botón "Continuar con Google". El inicio de sesión federado no está en el
/// MVP (el backend solo hace JWT + bcrypt), así que se muestra **deshabilitado**
/// con aviso "Disponible próximamente". Habilitarlo requiere OAuth en backend
/// y app.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Disponible próximamente',
      child: Opacity(
        opacity: 0.55,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              disabledForegroundColor: AppColors.textBody,
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.borderInput),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.lgAll,
              ),
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
      ),
    );
  }
}
