import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/chip_opcion.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/ilustracion_estado.dart';
import '../../../../core/widgets/miles_formatter.dart';

/// Botón de confirmación de las hojas: carga, deshabilitado hasta que se
/// pueda guardar y alto de 56.
class _BotonHoja extends StatelessWidget {
  const _BotonHoja({
    required this.etiqueta,
    required this.onPressed,
    this.cargando = false,
    this.icono,
  });

  final String etiqueta;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(
            alpha: cargando ? 0.7 : 0.38,
          ),
          foregroundColor: AppColors.onPrimary,
          disabledForegroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: cargando
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
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icono != null) ...<Widget>[
                    Icon(icono, size: 20),
                    const SizedBox(width: AppSpacing.x2),
                  ],
                  Flexible(child: Text(etiqueta, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

/// Confirmación explícita del cierre (acción sin retorno). Si quedan costos
/// estimados lo advierte, pero **no** decide si se permite: esa regla está
/// pendiente de definir y hoy el servidor deja cerrar.
class CerrarViajeSheet extends StatefulWidget {
  const CerrarViajeSheet({
    required this.remision,
    required this.costosEstimados,
    required this.alConfirmar,
    super.key,
  });

  final String remision;

  /// Descripciones de los costos que siguen sin valor real.
  final List<String> costosEstimados;
  final Future<void> Function() alConfirmar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String remision,
    required List<String> costosEstimados,
    required Future<void> Function() alConfirmar,
  }) => HojaInferior.mostrar<bool>(
    context,
    builder: (BuildContext _) => CerrarViajeSheet(
      remision: remision,
      costosEstimados: costosEstimados,
      alConfirmar: alConfirmar,
    ),
  );

  @override
  State<CerrarViajeSheet> createState() => _CerrarViajeSheetState();
}

class _CerrarViajeSheetState extends State<CerrarViajeSheet> {
  bool _cerrando = false;
  String? _error;

  Future<void> _cerrar() async {
    setState(() {
      _cerrando = true;
      _error = null;
    });
    try {
      await widget.alConfirmar();
      if (mounted) Navigator.of(context).pop(true);
    } on CatalogoFailure catch (falla) {
      if (!mounted) return;
      setState(() {
        _cerrando = false;
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
              child: const Icon(
                LucideIcons.lock,
                size: 22,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                '¿Cerrar el viaje ${widget.remision}?',
                style: AppTypography.subtitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        const Text(
          'Después de cerrarlo no se puede editar ni borrar. Si algo cambia, '
          'lo registras como ajuste, con su motivo.',
          style: AppTypography.body,
        ),
        if (widget.costosEstimados.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(
            tono: AppAlertTono.advertencia,
            mensaje:
                '${widget.costosEstimados.length == 1 ? 'Un costo sigue estimado' : '${widget.costosEstimados.length} costos siguen estimados'}: '
                '${widget.costosEstimados.join(', ')}. Se cerrará con ese valor.',
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _error!),
        ],
        const SizedBox(height: AppSpacing.x4),
        _BotonHoja(
          etiqueta: 'Cerrar viaje',
          icono: LucideIcons.lock,
          cargando: _cerrando,
          onPressed: _cerrar,
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _cerrando ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Ahora no'),
        ),
      ],
    );
  }
}

/// Éxito del cierre: ilustración de marca y un resumen sobrio.
class ViajeCerradoSheet extends StatelessWidget {
  const ViajeCerradoSheet({
    required this.remision,
    required this.resumen,
    super.key,
  });

  final String remision;
  final String resumen;

  static Future<void> mostrar(
    BuildContext context, {
    required String remision,
    required String resumen,
  }) => HojaInferior.mostrar<void>(
    context,
    builder: (BuildContext _) =>
        ViajeCerradoSheet(remision: remision, resumen: resumen),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Center(
          child: IlustracionEstadoView(IlustracionEstado.viajeCerrado),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Viaje $remision cerrado',
          style: AppTypography.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          resumen,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x4),
        _BotonHoja(
          etiqueta: 'Listo',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Un concepto que se puede ajustar: código (`FLETE` o categoría de costo),
/// etiqueta y valor vigente (texto, ya con los ajustes anteriores).
class ConceptoAjustable {
  const ConceptoAjustable({
    required this.codigo,
    required this.etiqueta,
    required this.valorActual,
  });

  final String codigo;
  final String etiqueta;
  final String valorActual;
}

/// Ajuste sobre un viaje cerrado: concepto, valor nuevo y **motivo
/// obligatorio**. El botón queda deshabilitado hasta completarlos. Queda
/// registrado con quién, cuándo y el valor anterior, y cambia la rentabilidad
/// del viaje.
class AjusteViajeSheet extends StatefulWidget {
  const AjusteViajeSheet({
    required this.conceptos,
    required this.alGuardar,
    super.key,
  });

  final List<ConceptoAjustable> conceptos;
  final Future<void> Function({
    required String motivo,
    required String concepto,
    required double valorNuevo,
  })
  alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required List<ConceptoAjustable> conceptos,
    required Future<void> Function({
      required String motivo,
      required String concepto,
      required double valorNuevo,
    })
    alGuardar,
  }) => HojaInferior.mostrar<bool>(
    context,
    builder: (BuildContext _) =>
        AjusteViajeSheet(conceptos: conceptos, alGuardar: alGuardar),
  );

  @override
  State<AjusteViajeSheet> createState() => _AjusteViajeSheetState();
}

class _AjusteViajeSheetState extends State<AjusteViajeSheet> {
  final TextEditingController _valor = TextEditingController();
  final TextEditingController _motivo = TextEditingController();
  int _seleccion = 0;
  bool _guardando = false;
  String? _error;

  bool get _completo =>
      _valor.text.replaceAll(RegExp(r'\D'), '').isNotEmpty &&
      _motivo.text.trim().isNotEmpty;

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final ConceptoAjustable c = widget.conceptos[_seleccion];
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alGuardar(
        motivo: _motivo.text.trim(),
        concepto: c.codigo,
        valorNuevo: double.parse(_valor.text.replaceAll(RegExp(r'\D'), '')),
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
        const Text('Registrar ajuste', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'Queda guardado con tu nombre, la fecha y el valor anterior, y cambia la rentabilidad del viaje.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: <Widget>[
            for (int i = 0; i < widget.conceptos.length; i++)
              ChipOpcion(
                etiqueta: widget.conceptos[i].etiqueta,
                seleccionado: i == _seleccion,
                onTap: _guardando ? null : () => setState(() => _seleccion = i),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Valor anterior: ${widget.conceptos[_seleccion].valorActual}',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x3),
        const Text('Valor nuevo', style: AppTypography.label),
        const SizedBox(height: AppSpacing.x1),
        TextField(
          controller: _valor,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          onChanged: (_) => setState(() {}),
          style: AppTypography.subtitle.copyWith(
            fontFeatures: AppTypography.tabular,
          ),
          decoration: const InputDecoration(prefixText: r'$ '),
        ),
        const SizedBox(height: AppSpacing.x3),
        const Text(
          'Motivo del ajuste · obligatorio',
          style: AppTypography.label,
        ),
        const SizedBox(height: AppSpacing.x1),
        TextField(
          controller: _motivo,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej.: el recibo llegó con otro valor',
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          _motivo.text.trim().isEmpty
              ? 'Sin motivo no se puede guardar.'
              : 'El motivo queda en el registro del viaje.',
          style: AppTypography.caption,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _error!),
        ],
        const SizedBox(height: AppSpacing.x4),
        _BotonHoja(
          etiqueta: 'Guardar ajuste',
          cargando: _guardando,
          onPressed: _completo ? _guardar : null,
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
