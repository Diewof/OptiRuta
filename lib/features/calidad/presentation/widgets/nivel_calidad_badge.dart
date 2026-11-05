import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/calidad.dart';

/// Icono y color de cada nivel. Una sola fuente para el badge, la tarjeta del
/// viaje y la pestaña «Calidad»: el color nunca va solo, siempre con icono y
/// etiqueta.
extension NivelCalidadVisual on NivelCalidad? {
  IconData get icono => switch (this) {
    NivelCalidad.verde => LucideIcons.circleCheck,
    NivelCalidad.ambar => LucideIcons.triangleAlert,
    NivelCalidad.rojo => LucideIcons.circleX,
    null => LucideIcons.circleDashed,
  };

  Color get color => switch (this) {
    NivelCalidad.verde => AppColors.success,
    NivelCalidad.ambar => AppColors.warning,
    NivelCalidad.rojo => AppColors.error,
    null => AppColors.textSecondary,
  };

  Color get fondo => switch (this) {
    NivelCalidad.verde => AppColors.successTint,
    NivelCalidad.ambar => AppColors.warningTint,
    NivelCalidad.rojo => AppColors.errorTint,
    null => AppColors.navyTint,
  };

  String get etiqueta => this?.etiqueta ?? 'Sin datos';
}

/// Insignia del nivel de calidad: icono + etiqueta.
class NivelCalidadBadge extends StatelessWidget {
  const NivelCalidadBadge({required this.nivel, super.key});

  final NivelCalidad? nivel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Calidad: ${nivel.etiqueta}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: nivel.fondo,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(nivel.icono, size: 14, color: nivel.color),
              const SizedBox(width: AppSpacing.x1),
              Text(
                nivel.etiqueta,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
