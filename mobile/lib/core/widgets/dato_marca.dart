import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'marca_icon.dart';

enum _Tipo { estimado, real, ajustado }

/// Marca de un dato automático: **estimado**, **real** o **ajustado**. Se
/// distinguen sin depender del color (símbolo, peso y etiqueta). La fuente
/// («Conductor», «GoPass»...) va como texto aparte, no cambia la marca.
class DatoMarca extends StatelessWidget {
  const DatoMarca.estimado(this.valor, {this.etiqueta = 'Est.', super.key})
    : _tipo = _Tipo.estimado;

  const DatoMarca.real(this.valor, {this.etiqueta = 'Real', super.key})
    : _tipo = _Tipo.real;

  const DatoMarca.ajustado(this.valor, {this.etiqueta = 'Ajustado', super.key})
    : _tipo = _Tipo.ajustado;

  /// Valor ya formateado (p. ej. `$3.050.000`).
  final String valor;

  /// Chip de texto; `null` o vacío lo oculta.
  final String? etiqueta;
  final _Tipo _tipo;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = AppTypography.body.copyWith(
      fontFeatures: AppTypography.tabular,
    );
    final TextStyle enfasis = base.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    final (String lectura, Widget contenido) = switch (_tipo) {
      _Tipo.estimado => (
        'Estimado: $valor',
        Text('≈ $valor', style: base.copyWith(color: AppColors.textSecondary)),
      ),
      _Tipo.real => (
        'Real: $valor',
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MarcaIcon(
              MarcaIconos.check,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.x1),
            Flexible(child: Text(valor, style: enfasis)),
          ],
        ),
      ),
      _Tipo.ajustado => (
        'Ajustado: $valor',
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MarcaIcon(
              MarcaIconos.datoAjustado,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.x1),
            Flexible(child: Text(valor, style: enfasis)),
          ],
        ),
      ),
    };

    final Color bordeChip = switch (_tipo) {
      _Tipo.estimado => AppColors.borderInput,
      _Tipo.real => AppColors.success,
      _Tipo.ajustado => AppColors.primary,
    };

    return Semantics(
      label: lectura,
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.x1,
          runSpacing: AppSpacing.x1,
          children: <Widget>[
            contenido,
            if (etiqueta != null && etiqueta!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.pillAll,
                  border: Border.all(color: bordeChip),
                ),
                child: Text(
                  etiqueta!,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _tipo == _Tipo.estimado
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
