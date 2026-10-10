import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Botón primario de autenticación: relleno plano de azul de acción, texto
/// blanco SemiBold, alto 56, `radius.md`. Único por pantalla; ocupa el ancho
/// disponible. (Desde la v2 ya no hay degradado: el primario es plano en toda
/// la app, igual que [PrimaryActionButton].)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.trailingIcon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Icono opcional a la derecha del texto (p. ej. flecha en "Ingresar").
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: AppColors.primary,
          borderRadius: AppRadius.mdAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            overlayColor: const WidgetStatePropertyAll<Color>(
              AppColors.pressedOverlay,
            ),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.onPrimary,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          if (trailingIcon != null) ...<Widget>[
                            const SizedBox(width: 10),
                            Icon(
                              trailingIcon,
                              size: 20,
                              color: AppColors.onPrimary,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
