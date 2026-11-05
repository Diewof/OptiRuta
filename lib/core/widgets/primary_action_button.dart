import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Botón primario plano de las pantallas operativas (no auth): relleno
/// `color.action.primary` (#1E3A5F), texto blanco SemiBold, alto 48,
/// `radius.md`. Único por pantalla (sistema-de-diseno.md §5).
///
/// A diferencia de [PrimaryButton] (degradado, solo auth), este es el botón
/// primario del resto de la app: Agendar viaje, Agregar conductor, etc.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.leadingIcon,
    this.grande = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Icono opcional a la izquierda del texto (p. ej. "+" en "Agendar viaje").
  final IconData? leadingIcon;

  /// Botón de acción principal fijo al pie (56 de alto en vez de 48).
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;

    return SizedBox(
      height: grande ? 56 : 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          foregroundColor: AppColors.onPrimary,
          disabledForegroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: grande ? 16 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                  if (leadingIcon != null) ...<Widget>[
                    Icon(leadingIcon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
