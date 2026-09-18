import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Botón primario de autenticación: relleno con degradado azul (navy → azul de
/// acción → azul de tránsito), texto blanco SemiBold, alto 52, `radius.lg`.
///
/// El degradado es una excepción acotada a las pantallas de auth
/// (ver sistema-de-diseno.md §1); el resto de la app usa acción plana.
/// Único por pantalla. Ocupa el ancho disponible del contenedor.
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
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                AppColors.authGradientStart,
                AppColors.authGradientMid,
                AppColors.authGradientEnd,
              ],
            ),
            borderRadius: AppRadius.lgAll,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: AppRadius.lgAll,
              overlayColor: const WidgetStatePropertyAll<Color>(
                AppColors.pressedOverlay,
              ),
              child: SizedBox(
                height: 52,
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
                                fontSize: 15,
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
      ),
    );
  }
}
