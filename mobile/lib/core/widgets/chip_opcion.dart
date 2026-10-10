import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Chip de selección única (pill, 48 de alto): fondo tinte y borde azul de
/// acción cuando está seleccionado.
class ChipOpcion extends StatelessWidget {
  const ChipOpcion({
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
    super.key,
  });

  final String etiqueta;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: etiqueta,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: seleccionado ? AppColors.navyTint : AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: seleccionado ? AppColors.primary : AppColors.borderInput,
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            alignment: Alignment.center,
            child: Text(
              etiqueta,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
