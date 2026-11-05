import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../domain/entities/tipo_hito.dart';
import 'hito_timeline.dart';

/// Hoja de confirmación de un hito. Segundo (y último) toque desde Inicio:
/// muestra qué se va a registrar y con qué hora, guarda y se cierra. Si el
/// guardado falla, el error se explica dentro de la hoja y se puede reintentar.
class RegistrarHitoSheet extends StatefulWidget {
  const RegistrarHitoSheet({
    required this.tipo,
    required this.descripcionViaje,
    required this.alConfirmar,
    super.key,
  });

  final TipoHito tipo;

  /// Línea de contexto bajo el título (p. ej. «Medellín → Cartagena»).
  final String descripcionViaje;

  /// Guarda el hito. Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function() alConfirmar;

  /// Devuelve `true` si el hito quedó registrado.
  static Future<bool?> mostrar(
    BuildContext context, {
    required TipoHito tipo,
    required String descripcionViaje,
    required Future<void> Function() alConfirmar,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => RegistrarHitoSheet(
        tipo: tipo,
        descripcionViaje: descripcionViaje,
        alConfirmar: alConfirmar,
      ),
    );
  }

  @override
  State<RegistrarHitoSheet> createState() => _RegistrarHitoSheetState();
}

class _RegistrarHitoSheetState extends State<RegistrarHitoSheet> {
  final DateTime _hora = DateTime.now();
  bool _guardando = false;
  bool _guardado = false;
  String? _error;

  Future<void> _confirmar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alConfirmar();
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _guardado = true;
      });
      await Future<void>.delayed(
        AppMotion.efectiva(context, const Duration(milliseconds: 420)),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = falla.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.navyTint,
                borderRadius: AppRadius.mdAll,
              ),
              alignment: Alignment.center,
              child: MarcaIcon(
                HitoTimeline.iconoDe(widget.tipo),
                size: 22,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.tipo.etiqueta, style: AppTypography.subtitle),
                  Text(
                    widget.descripcionViaje,
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hora',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      'La toma el celular',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                formatearHora(_hora),
                style: AppTypography.display.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                LucideIcons.info,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                'Se guarda con la hora de tu celular y no se puede deshacer.',
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _error!),
        ],
        const SizedBox(height: AppSpacing.x4),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _guardando || _guardado ? null : _confirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              disabledForegroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll,
              ),
              textStyle: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.efectiva(context, AppMotion.fast),
              child: _guardando
                  ? const SizedBox(
                      key: ValueKey<String>('guardando'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.onPrimary,
                        ),
                      ),
                    )
                  : _guardado
                  ? const Row(
                      key: ValueKey<String>('guardado'),
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(LucideIcons.check, size: 22),
                        SizedBox(width: AppSpacing.x2),
                        Text('Guardado'),
                      ],
                    )
                  : const Text('Confirmar', key: ValueKey<String>('confirmar')),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _guardando || _guardado
              ? null
              : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
