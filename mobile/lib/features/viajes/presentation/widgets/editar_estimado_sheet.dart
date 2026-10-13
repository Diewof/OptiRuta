import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/miles_formatter.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Hoja del administrador para corregir el valor estimado de un costo.
class EditarEstimadoSheet extends StatefulWidget {
  const EditarEstimadoSheet({
    required this.etiqueta,
    required this.estimado,
    required this.alGuardar,
    super.key,
  });

  final String etiqueta;
  final double estimado;

  /// Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function(double valor) alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String etiqueta,
    required double estimado,
    required Future<void> Function(double valor) alGuardar,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => EditarEstimadoSheet(
        etiqueta: etiqueta,
        estimado: estimado,
        alGuardar: alGuardar,
      ),
    );
  }

  @override
  State<EditarEstimadoSheet> createState() => _EditarEstimadoSheetState();
}

class _EditarEstimadoSheetState extends State<EditarEstimadoSheet> {
  late final TextEditingController _valor = TextEditingController(
    text: MilesFormatter.conMiles(widget.estimado.round().toString()),
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final double? v = double.tryParse(
      _valor.text.replaceAll(RegExp(r'\D'), ''),
    );
    if (v == null) {
      setState(() => _error = 'Escribe el valor estimado.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.alGuardar(v);
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
        Text('Estimado · ${widget.etiqueta}', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'Es el valor planeado. El conductor confirma después el valor real.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _valor,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          decoration: const InputDecoration(
            labelText: 'Valor estimado',
            prefixText: r'$ ',
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _error!),
        ],
        const SizedBox(height: AppSpacing.x4),
        PrimaryActionButton(
          label: 'Guardar estimado',
          grande: true,
          loading: _guardando,
          onPressed: _guardar,
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
