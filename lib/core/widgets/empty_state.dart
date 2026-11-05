import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ilustracion_estado.dart';

/// Estado vacío reutilizable para listados sin resultados (sin datos, sin
/// coincidencias de búsqueda, etc.).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.mensaje,
    this.icono = LucideIcons.inbox,
    this.titulo,
    this.ilustracion,
    super.key,
  });

  final String mensaje;
  final IconData icono;
  final String? titulo;

  /// Ilustración de marca (en vez del icono). Máximo una por pantalla.
  final IlustracionEstado? ilustracion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (ilustracion != null)
              IlustracionEstadoView(ilustracion!)
            else
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.navyTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 30, color: AppColors.navy),
              ),
            const SizedBox(height: AppSpacing.x3),
            if (titulo != null) ...<Widget>[
              Text(
                titulo!,
                textAlign: TextAlign.center,
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: AppSpacing.x1),
            ],
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
