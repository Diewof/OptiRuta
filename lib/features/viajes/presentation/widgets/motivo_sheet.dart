import 'package:flutter/material.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';

/// Hoja que pide un motivo (mínimo 5 caracteres) antes de una acción
/// irreversible o destructiva: cancelar o eliminar un viaje.
class MotivoSheet extends StatefulWidget {
  const MotivoSheet({
    required this.titulo,
    required this.mensaje,
    required this.textoConfirmar,
    required this.alConfirmar,
    this.destructivo = true,
    super.key,
  });

  final String titulo;
  final String mensaje;
  final String textoConfirmar;
  final bool destructivo;

  /// Ejecuta la acción. Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function(String motivo) alConfirmar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    required Future<void> Function(String motivo) alConfirmar,
    bool destructivo = true,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => MotivoSheet(
        titulo: titulo,
        mensaje: mensaje,
        textoConfirmar: textoConfirmar,
        destructivo: destructivo,
        alConfirmar: alConfirmar,
      ),
    );
  }

  @override
  State<MotivoSheet> createState() => _MotivoSheetState();
}

class _MotivoSheetState extends State<MotivoSheet> {
  final TextEditingController _motivo = TextEditingController();
  bool _procesando = false;
  String? _errorCampo;
  String? _errorAccion;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final String motivo = _motivo.text.trim();
    if (motivo.length < 5) {
      setState(() => _errorCampo = 'Escribe un motivo de al menos 5 letras.');
      return;
    }
    setState(() {
      _procesando = true;
      _errorCampo = null;
      _errorAccion = null;
    });
    try {
      await widget.alConfirmar(motivo);
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _errorAccion = falla.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.titulo, style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        Text(widget.mensaje, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _motivo,
          maxLength: 200,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Motivo',
            errorText: _errorCampo,
          ),
        ),
        if (_errorAccion != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x2),
          AppAlert(mensaje: _errorAccion!),
        ],
        const SizedBox(height: AppSpacing.x3),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _procesando ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.destructivo
                  ? AppColors.brandRed
                  : AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledBackgroundColor:
                  (widget.destructivo ? AppColors.brandRed : AppColors.primary)
                      .withValues(alpha: 0.6),
              disabledForegroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll,
              ),
            ),
            child: _procesando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.onPrimary,
                      ),
                    ),
                  )
                : Text(widget.textoConfirmar),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _procesando
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
      ],
    );
  }
}
