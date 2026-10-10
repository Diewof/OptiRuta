import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'marca_icon.dart';

/// Estado del semáforo de rentabilidad. **Lo calcula el servidor** (umbrales
/// configurables y por definir): la app solo lo dibuja. Cada estado tiene una
/// forma distinta (círculo con check, triángulo, círculo con ✕, círculo
/// discontinuo) para no depender solo del color.
enum SemaforoRentabilidad {
  rentable('Rentable', 'sem_ok', AppColors.successTint),
  margenBajo('Margen bajo', 'sem_warn', AppColors.warningTint),
  perdida('Pérdida', 'sem_bad', AppColors.errorTint),
  sinDatos('Sin datos suficientes', 'sem_none', AppColors.navyTint);

  const SemaforoRentabilidad(this.etiqueta, this.icono, this.fondo);

  /// Etiqueta por defecto. Pendiente de confirmar con el dueño del producto.
  final String etiqueta;
  final String icono;
  final Color fondo;
}

/// Chip de semáforo: icono + etiqueta, nunca solo color.
class SemaforoBadge extends StatelessWidget {
  const SemaforoBadge({
    required this.estado,
    this.etiqueta,
    this.compacto = false,
    super.key,
  });

  final SemaforoRentabilidad estado;

  /// Reemplaza la etiqueta por defecto (las etiquetas son configurables).
  final String? etiqueta;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final double icono = compacto ? 14 : 18;
    final String texto = etiqueta ?? estado.etiqueta;
    return Semantics(
      label: 'Rentabilidad: $texto',
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: compacto ? 24 : 28),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x2,
            2,
            AppSpacing.x3,
            2,
          ),
          decoration: BoxDecoration(
            color: estado.fondo,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SvgPicture.asset(
                'assets/icons/${estado.icono}.svg',
                width: icono,
                height: icono,
              ),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  texto,
                  style: AppTypography.label.copyWith(
                    fontSize: compacto ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Qué tan firme es el número de rentabilidad.
enum BaseCalculo {
  proyectada('Proyectada', MarcaIconos.datoEstimado),
  parcial('Parcial', MarcaIconos.datoParcial),
  confirmada('Confirmada', MarcaIconos.datoReal),
  ajustada('Ajustada', MarcaIconos.datoAjustado);

  const BaseCalculo(this.etiqueta, this.icono);
  final String etiqueta;
  final MarcaIconos icono;
}

/// Etiqueta de base de cálculo (proyectada → parcial → confirmada → ajustada).
class BaseCalculoChip extends StatelessWidget {
  const BaseCalculoChip({
    required this.base,
    this.sobreOscuro = false,
    super.key,
  });

  final BaseCalculo base;

  /// `true` sobre superficies navy (texto y borde blancos).
  final bool sobreOscuro;

  @override
  Widget build(BuildContext context) {
    final Color color = sobreOscuro ? Colors.white : AppColors.textSecondary;
    final Color borde = sobreOscuro
        ? const Color(0x73FFFFFF)
        : AppColors.borderInput;
    return Semantics(
      label: 'Base del cálculo: ${base.etiqueta}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MarcaIcon(base.icono, size: 12, color: color),
              const SizedBox(width: AppSpacing.x1),
              Text(
                base.etiqueta,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
