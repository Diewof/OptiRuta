import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'marca_icon.dart';

/// Viaje con retraso (RF-20). Ámbar sólido con texto navy: el contraste
/// llega a 4,9:1 y el reloj + el texto evitan depender solo del color.
class RetrasoBadge extends StatelessWidget {
  const RetrasoBadge({this.etiqueta = 'Con retraso', super.key});

  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: 2,
          ),
          decoration: const BoxDecoration(
            color: AppColors.warning,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const MarcaIcon(
                MarcaIconos.retraso,
                size: 14,
                color: AppColors.navy,
              ),
              const SizedBox(width: AppSpacing.x1),
              Text(
                etiqueta,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
