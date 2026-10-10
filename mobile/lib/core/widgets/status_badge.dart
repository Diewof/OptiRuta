import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tono de un [StatusBadge]. El color solo se usa como relleno/borde/icono,
/// nunca como fondo completo de pantalla ni fila (sistema-de-diseno.md §1/§4).
enum StatusTone { success, warning, error, neutral }

/// Badge de estado: color + icono + texto, nunca solo color.
///
/// Relleno del color de estado al 12–16 %, texto e icono del color de estado
/// a intensidad plena salvo advertencia (texto oscuro sobre ámbar).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.tone, super.key});

  /// Atajo para el par activo/inactivo, el caso mas comun en los listados.
  factory StatusBadge.activo(bool activo) => StatusBadge(
    label: activo ? 'Activo' : 'Inactivo',
    tone: activo ? StatusTone.success : StatusTone.neutral,
  );

  final String label;
  final StatusTone tone;

  Color get _colorTexto => switch (tone) {
    StatusTone.success => AppColors.success,
    StatusTone.warning => AppColors.textPrimary,
    StatusTone.error => AppColors.error,
    StatusTone.neutral => AppColors.textSecondary,
  };

  Color get _colorRelleno => switch (tone) {
    StatusTone.success => AppColors.successTint,
    StatusTone.warning => AppColors.warning,
    StatusTone.error => AppColors.errorTint,
    StatusTone.neutral => AppColors.navyTint,
  };

  IconData get _icono => switch (tone) {
    StatusTone.success => LucideIcons.circleCheck,
    StatusTone.warning => LucideIcons.triangleAlert,
    StatusTone.error => LucideIcons.circleAlert,
    StatusTone.neutral => LucideIcons.circleMinus,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x1,
          ),
          decoration: BoxDecoration(
            color: _colorRelleno,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_icono, size: 14, color: _colorTexto),
              const SizedBox(width: AppSpacing.x1),
              Text(
                label,
                style: AppTypography.label.copyWith(color: _colorTexto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
