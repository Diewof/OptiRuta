import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/secondary_button.dart';

/// Marcador de posición para secciones aún no implementadas.
class WorkInProgressPage extends StatelessWidget {
  const WorkInProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onNavy,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandMark(size: 26),
            const SizedBox(width: AppSpacing.x2),
            Text(
              'OptiRuta',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.onNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: ColoredBox(
            color: AppColors.brandRed,
            child: SizedBox(height: 2, width: double.infinity),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.navyTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.hardHat,
                    size: 30,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                Semantics(
                  header: true,
                  child: Text(
                    'TRABAJO EN PROGRESO',
                    textAlign: TextAlign.center,
                    style: AppTypography.title.copyWith(letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Esta sección aún está en construcción. '
                  'Pronto estará disponible.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                SecondaryButton(
                  label: 'Volver',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
