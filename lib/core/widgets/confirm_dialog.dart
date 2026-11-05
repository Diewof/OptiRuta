import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primary_action_button.dart';
import 'secondary_button.dart';

/// Diálogo de confirmación genérico (p. ej. "¿Cerrar sesión?"): icono,
/// título, mensaje, cancelar (outline) + confirmar (rojo de marca si
/// [esDestructivo], azul de acción si no).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.titulo,
    required this.mensaje,
    required this.icono,
    this.textoConfirmar = 'Confirmar',
    this.textoCancelar = 'Cancelar',
    this.esDestructivo = false,
    super.key,
  });

  final String titulo;
  final String mensaje;
  final IconData icono;
  final String textoConfirmar;
  final String textoCancelar;
  final bool esDestructivo;

  /// Muestra el diálogo y resuelve `true` si se confirmó, `false`/`null` si
  /// se canceló o se descartó.
  static Future<bool?> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required IconData icono,
    String textoConfirmar = 'Confirmar',
    String textoCancelar = 'Cancelar',
    bool esDestructivo = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        titulo: titulo,
        mensaje: mensaje,
        icono: icono,
        textoConfirmar: textoConfirmar,
        textoCancelar: textoCancelar,
        esDestructivo: esDestructivo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x6,
          AppSpacing.x4,
          AppSpacing.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                borderRadius: AppRadius.lgAll,
              ),
              child: Icon(icono, color: AppColors.brandRed),
            ),
            const SizedBox(height: AppSpacing.x3),
            Semantics(
              header: true,
              child: Text(titulo, style: AppTypography.title),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(mensaje, style: AppTypography.body),
            const SizedBox(height: AppSpacing.x4),
            Column(
              children: <Widget>[
                if (esDestructivo)
                  _DestructiveButton(
                    label: textoConfirmar,
                    onPressed: () => Navigator.of(context).pop(true),
                  )
                else
                  PrimaryActionButton(
                    label: textoConfirmar,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                const SizedBox(height: AppSpacing.x2),
                SecondaryButton(
                  label: textoCancelar,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: AppColors.onBrandRed,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
