import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/pages/work_in_progress_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/conductor_scaffold.dart';
import '../../../../core/widgets/conductor_section.dart';
import '../../../autenticacion/domain/entities/usuario.dart';

/// Manual de usuario del Conductor (vista 07 del diseño): guías rápidas de
/// uso en campo. El contenido de cada guía todavía no existe (fuera del
/// alcance de esta tarea); cada enlace lleva al marcador de "trabajo en
/// progreso" compartido por la app en vez de inventar texto de ayuda.
class ConductorManualPage extends StatelessWidget {
  const ConductorManualPage({required this.usuario, super.key});

  final Usuario usuario;

  static const List<(IconData, String)> _guias = <(IconData, String)>[
    (LucideIcons.mapPin, 'Cómo consultar tu viaje asignado'),
    (LucideIcons.milestone, 'Cómo registrar los hitos del viaje'),
    (LucideIcons.fuel, 'Cómo registrar el ACPM real y otros costos'),
    (LucideIcons.wifiOff, 'Qué hacer sin conexión a internet'),
    (LucideIcons.circleHelp, 'Preguntas frecuentes'),
  ];

  @override
  Widget build(BuildContext context) {
    return ConductorScaffold(
      titulo: 'Manual de usuario',
      seccionActual: ConductorSection.manual,
      usuario: usuario,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          Text(
            'Guías rápidas para usar la aplicación en campo.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _guias.length; i++)
                  _ItemGuia(
                    icono: _guias[i].$1,
                    titulo: _guias[i].$2,
                    conBorde: i > 0,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppCard(
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: AppRadius.mdAll,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.phone,
                    size: 18,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '¿Necesitas ayuda?',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Contacta a tu administrador para soporte.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemGuia extends StatelessWidget {
  const _ItemGuia({
    required this.icono,
    required this.titulo,
    required this.conBorde,
  });

  final IconData icono;
  final String titulo;
  final bool conBorde;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: conBorde
            ? const Border(top: BorderSide(color: AppColors.dividerTable))
            : null,
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const WorkInProgressPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: AppRadius.mdAll,
                ),
                alignment: Alignment.center,
                child: Icon(icono, size: 18, color: AppColors.navy),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  titulo,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
