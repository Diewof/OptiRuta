import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Dirección de la tendencia mostrada en un [KpiTile].
enum KpiTrend { up, down, none }

/// Tarjeta de indicador clave (KPI) de Analítica: etiqueta, valor grande en
/// cifras tabulares, icono y variación opcional frente al período anterior.
class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.etiqueta,
    required this.valor,
    this.icono,
    this.varianza,
    this.tendencia = KpiTrend.none,
    this.tendenciaEsPositiva = true,
    this.stripeColor = AppColors.navy,
    super.key,
  });

  final String etiqueta;
  final String valor;
  final IconData? icono;

  /// Texto de variación, p. ej. "8,4 % vs. ago.".
  final String? varianza;
  final KpiTrend tendencia;

  /// Si la tendencia mostrada representa una mejora (verde) o un deterioro
  /// (ámbar/rojo se decide por el llamador vía [tendenciaEsPositiva]).
  final bool tendenciaEsPositiva;
  final Color stripeColor;

  @override
  Widget build(BuildContext context) {
    final Color colorTendencia = tendenciaEsPositiva
        ? AppColors.success
        : AppColors.warning;

    return AppCard(
      stripe: AppCardStripe.top,
      stripeColor: stripeColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  etiqueta,
                  style: AppTypography.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icono != null) Icon(icono, size: 16, color: AppColors.slate),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            valor,
            style: AppTypography.title.copyWith(
              fontSize: 24,
              height: 30 / 24,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (varianza != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x1),
            Row(
              children: <Widget>[
                if (tendencia != KpiTrend.none)
                  Icon(
                    tendencia == KpiTrend.up
                        ? LucideIcons.arrowUp
                        : LucideIcons.arrowDown,
                    size: 14,
                    color: colorTendencia,
                  ),
                const SizedBox(width: AppSpacing.x1),
                Expanded(
                  child: Text(
                    varianza!,
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
