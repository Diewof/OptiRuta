import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../validation/validation_rule.dart';

/// Lista vertical de reglas de validación que se actualiza en vivo mientras la
/// persona escribe.
///
/// - Regla cumplida: check verde.
/// - Regla pendiente (sin intento de envío): círculo neutro.
/// - Regla pendiente tras intentar enviar ([showErrors] = true): marca roja.
///
/// Cuando todas las reglas se cumplen, la lista se colapsa en un único mensaje
/// de confirmación ([validMessage]) en lugar de mostrar cada regla en verde.
class LiveValidationChecklist extends StatelessWidget {
  const LiveValidationChecklist({
    required this.rules,
    required this.value,
    this.showErrors = false,
    this.validMessage = 'Campo válido',
    super.key,
  });

  final List<ValidationRule> rules;
  final String value;
  final bool showErrors;
  final String validMessage;

  @override
  Widget build(BuildContext context) {
    final bool allOk = rules.every((ValidationRule r) => r.test(value));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2, left: AppSpacing.x1),
      child: allOk
          ? _ValidRow(message: validMessage)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final ValidationRule rule in rules)
                  _ChecklistRow(
                    key: ValueKey<String>(rule.label),
                    label: rule.label,
                    ok: rule.test(value),
                    showErrors: showErrors,
                  ),
              ],
            ),
    );
  }
}

/// Mensaje único de confirmación cuando el campo cumple todas las reglas.
class _ValidRow extends StatelessWidget {
  const _ValidRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.success,
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

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.ok,
    required this.showErrors,
    super.key,
  });

  final String label;
  final bool ok;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final Color color = ok
        ? AppColors.success
        : showErrors
        ? AppColors.error
        : AppColors.textSecondary;

    final IconData icon = ok
        ? Icons.check_circle_outline
        : showErrors
        ? Icons.cancel_outlined
        : Icons.radio_button_unchecked;

    final String estado = ok
        ? 'cumplido'
        : showErrors
        ? 'falta'
        : 'pendiente';

    return Semantics(
      label: '$label: $estado',
      liveRegion: showErrors && !ok,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (Widget child, Animation<double> anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  icon,
                  key: ValueKey<IconData>(icon),
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: ok ? AppColors.textSecondary : color,
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
