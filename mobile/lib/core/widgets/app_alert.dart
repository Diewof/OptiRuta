import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Severidad de una alerta. Define el color de acento (borde e icono).
enum AppAlertTono { error, advertencia, exito }

/// Alerta / banner del sistema de diseno (sistema-de-diseno.md seccion 5):
/// borde izquierdo de 3 px con el color de estado, fondo blanco, icono +
/// titulo opcional + cuerpo. No ocupa el fondo completo ni depende solo del
/// color (siempre lleva icono y texto).
class AppAlert extends StatelessWidget {
  const AppAlert({
    required this.mensaje,
    this.titulo,
    this.tono = AppAlertTono.error,
    super.key,
  });

  final String mensaje;
  final String? titulo;
  final AppAlertTono tono;

  Color get _acento => switch (tono) {
    AppAlertTono.error => AppColors.error,
    AppAlertTono.advertencia => AppColors.warning,
    AppAlertTono.exito => AppColors.success,
  };

  IconData get _icono => switch (tono) {
    AppAlertTono.error => Icons.error_outline,
    AppAlertTono.advertencia => Icons.warning_amber_outlined,
    AppAlertTono.exito => Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.mdAll,
          border: Border(left: BorderSide(color: _acento, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x3,
            AppSpacing.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_icono, size: 18, color: _acento),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (titulo != null) ...<Widget>[
                      Text(
                        titulo!,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                    ],
                    Text(
                      mensaje,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
