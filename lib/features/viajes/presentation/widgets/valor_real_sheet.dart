import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../../../core/widgets/miles_formatter.dart';

String _conMiles(double valor) =>
    MilesFormatter.conMiles(valor.round().toString());

/// Hoja para confirmar el valor real de un costo. El valor estimado llega
/// precargado y **se ve como automático** (borde discontinuo, fondo gris,
/// etiqueta «Est.»); al editarlo pasa a campo normal con etiqueta «Real».
///
/// El conductor solo confirma el `valor_real` de costos que ya existen: nunca
/// crea categorías nuevas (RLS).
class ValorRealSheet extends StatefulWidget {
  const ValorRealSheet({
    required this.etiqueta,
    required this.estimado,
    required this.alGuardar,
    this.valorReal,
    super.key,
  });

  final String etiqueta;
  final double estimado;
  final double? valorReal;

  /// Guarda el valor real. Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function(double valor) alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String etiqueta,
    required double estimado,
    required Future<void> Function(double valor) alGuardar,
    double? valorReal,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => ValorRealSheet(
        etiqueta: etiqueta,
        estimado: estimado,
        valorReal: valorReal,
        alGuardar: alGuardar,
      ),
    );
  }

  @override
  State<ValorRealSheet> createState() => _ValorRealSheetState();
}

class _ValorRealSheetState extends State<ValorRealSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: _conMiles(widget.valorReal ?? widget.estimado),
  );
  final FocusNode _foco = FocusNode();

  /// `true` mientras el valor sigue siendo el estimado sin tocar.
  late bool _automatico = widget.valorReal == null;
  bool _guardando = false;
  String? _errorCampo;
  String? _errorGuardado;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (_foco.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final double? valor = double.tryParse(
      _controller.text.replaceAll(RegExp(r'\D'), ''),
    );
    if (valor == null || valor <= 0) {
      setState(
        () => _errorCampo = 'Escribe el valor que pagaste para guardarlo.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });
    try {
      await widget.alGuardar(valor);
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = falla.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool error = _errorCampo != null;
    final Color borde = error ? AppColors.error : AppColors.borderInput;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Valor real · ${widget.etiqueta}', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'Escribe lo que pagaste. Si coincide con el estimado, solo guárdalo.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        Text(
          'Valor de ${widget.etiqueta.toLowerCase()}',
          style: AppTypography.label,
        ),
        const SizedBox(height: AppSpacing.x1),
        CustomPaint(
          foregroundPainter: _automatico
              ? const _BordeDiscontinuo(color: AppColors.textSecondary)
              : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
            decoration: BoxDecoration(
              color: _automatico ? AppColors.canvas : AppColors.card,
              borderRadius: AppRadius.mdAll,
              border: _automatico
                  ? null
                  : Border.all(color: borde, width: error ? 2 : 1),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  r'$',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _foco,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[MilesFormatter()],
                    style: AppTypography.subtitle.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (String _) => setState(() {
                      _automatico = false;
                      _errorCampo = null;
                    }),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.pillAll,
                    border: Border.all(
                      color: _automatico
                          ? AppColors.borderInput
                          : AppColors.success,
                    ),
                  ),
                  child: Text(
                    _automatico ? 'Est.' : 'Real',
                    style: AppTypography.caption.copyWith(
                      color: _automatico
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: MarcaIcon(
                error ? MarcaIconos.alerta : MarcaIconos.datoEstimado,
                size: 14,
                color: error ? AppColors.error : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.x1),
            Expanded(
              child: Text(
                error
                    ? _errorCampo!
                    : _automatico
                    ? 'Estimado por el sistema. Cámbialo por lo que pagaste.'
                    : 'Este valor quedará como real.',
                style: AppTypography.caption.copyWith(
                  color: error ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (_errorGuardado != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _errorGuardado!),
        ],
        const SizedBox(height: AppSpacing.x4),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
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
            child: _guardando
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
                : const Text('Guardar como real'),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
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

/// Borde discontinuo redondeado: marca visualmente un valor automático.
class _BordeDiscontinuo extends CustomPainter {
  const _BordeDiscontinuo({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path trazo = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.md),
        ),
      );
    final Paint pintura = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metrica in trazo.computeMetrics()) {
      double d = 0;
      while (d < metrica.length) {
        canvas.drawPath(metrica.extractPath(d, d + 5), pintura);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_BordeDiscontinuo old) => old.color != color;
}
