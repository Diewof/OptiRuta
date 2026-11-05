import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Campo de selección de solo lectura (cliente, vehículo, conductor, fecha,
/// hora): label siempre visible, valor elegido o marcador de posición,
/// chevron, `onTap` abre el selector correspondiente (bottom sheet, date
/// picker, etc.). Misma altura y bordes que [AppTextField] para que ambos
/// convivan en el mismo formulario.
class AppSelectField extends StatelessWidget {
  const AppSelectField({
    required this.label,
    required this.onTap,
    this.valor,
    this.marcador = 'Seleccionar',
    this.icono,
    this.errorText,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? valor;
  final String marcador;
  final IconData? icono;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool tieneValor = valor != null && valor!.isNotEmpty;
    final Color borderColor = errorText != null
        ? AppColors.error
        : AppColors.borderInput;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.x1),
        Semantics(
          button: true,
          label: label,
          value: tieneValor ? valor : marcador,
          child: Material(
            color: AppColors.card,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: onTap,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  children: <Widget>[
                    if (icono != null) ...<Widget>[
                      Icon(icono, size: 20, color: AppColors.slate),
                      const SizedBox(width: AppSpacing.x2),
                    ],
                    Expanded(
                      child: Text(
                        tieneValor ? valor! : marcador,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: tieneValor
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: AppColors.textBody,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x1),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.x1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  LucideIcons.circleAlert,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
