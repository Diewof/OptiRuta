import 'package:flutter/material.dart';

import '../accessibility/announce.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../validation/validation_rule.dart';
import 'validation_checklist.dart';

/// Input de texto de OptiRuta.
///
/// - Label flotante siempre visible, asociada al campo para lectores de
///   pantalla, e icono guía opcional a la izquierda.
/// - Mostrar/ocultar contraseña con label semántico y anuncio.
/// - Validación: si se pasan [rules], bajo el campo aparece una checklist en
///   vivo (una regla por línea) en cuanto la persona empieza a escribir. Las
///   reglas incumplidas se marcan en rojo solo cuando [showRuleErrors] es
///   `true` (tras intentar enviar). Sin [rules], se usa [errorText] como
///   mensaje único con aparición animada.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    this.focusNode,
    this.prefixIcon,
    this.hint,
    this.errorText,
    this.rules,
    this.showRuleErrors = false,
    this.validMessage = 'Campo válido',
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final IconData? prefixIcon;

  /// Texto de ejemplo dentro del campo (además del label, nunca en su lugar).
  final String? hint;
  final String? errorText;
  final List<ValidationRule>? rules;
  final bool showRuleErrors;

  /// Mensaje único que reemplaza la checklist cuando el campo cumple todas
  /// las reglas.
  final String validMessage;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.isPassword;

  @override
  void initState() {
    super.initState();
    if (widget.rules != null) {
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      if (widget.rules != null) {
        widget.controller.addListener(_onTextChanged);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _toggleObscure() {
    setState(() => _obscure = !_obscure);
    announceForAccessibility(
      context,
      _obscure ? 'Contraseña oculta' : 'Contraseña visible',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null || widget.showRuleErrors;
    final String text = widget.controller.text;
    final bool showChecklist = widget.rules != null && text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscure,
          enableSuggestions: !widget.isPassword,
          autocorrect: !widget.isPassword,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          style: AppTypography.body,
          cursorColor: AppColors.brandRed,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            errorText: hasError ? (widget.errorText ?? ' ') : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 52,
            ),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x2,
                      AppSpacing.x2,
                      AppSpacing.x1,
                      AppSpacing.x2,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(
                        widget.prefixIcon,
                        size: 20,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    onPressed: _toggleObscure,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 22,
                    ),
                    color: AppColors.textSecondary,
                    tooltip: _obscure
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  )
                : null,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          curve: Curves.easeOut,
          child: _buildBelow(showChecklist: showChecklist),
        ),
      ],
    );
  }

  Widget _buildBelow({required bool showChecklist}) {
    if (showChecklist) {
      return LiveValidationChecklist(
        rules: widget.rules!,
        value: widget.controller.text,
        showErrors: widget.showRuleErrors,
        validMessage: widget.validMessage,
      );
    }
    if (widget.rules == null && widget.errorText != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2, left: AppSpacing.x1),
        child: _ErrorLine(message: widget.errorText!),
      );
    }
    return const SizedBox(width: double.infinity);
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(message),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (BuildContext context, double t, Widget? child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * -4),
              child: child,
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                message,
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
