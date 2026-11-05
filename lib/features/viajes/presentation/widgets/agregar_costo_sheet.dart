import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/miles_formatter.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Hoja para anotar un costo adicional libre del viaje (RF-14): una
/// descripción corta y lo que se pagó. Siempre queda como valor real.
class AgregarCostoSheet extends StatefulWidget {
  const AgregarCostoSheet({
    required this.alGuardar,
    this.comoEstimado = false,
    super.key,
  });

  /// El administrador anota el valor planeado; el conductor, lo ya pagado.
  final bool comoEstimado;

  /// Guarda el costo. Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function(String descripcion, double valor) alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required Future<void> Function(String descripcion, double valor) alGuardar,
    bool comoEstimado = false,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) =>
          AgregarCostoSheet(alGuardar: alGuardar, comoEstimado: comoEstimado),
    );
  }

  @override
  State<AgregarCostoSheet> createState() => _AgregarCostoSheetState();
}

class _AgregarCostoSheetState extends State<AgregarCostoSheet> {
  final TextEditingController _descripcion = TextEditingController();
  final TextEditingController _valor = TextEditingController();
  bool _guardando = false;
  String? _errorDescripcion;
  String? _errorValor;
  String? _errorGuardado;

  @override
  void dispose() {
    _descripcion.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final String descripcion = _descripcion.text.trim();
    final double? valor = double.tryParse(
      _valor.text.replaceAll(RegExp(r'\D'), ''),
    );
    setState(() {
      _errorDescripcion = descripcion.isEmpty
          ? 'Describe en qué fue el gasto.'
          : null;
      _errorValor = valor == null || valor <= 0
          ? 'Escribe lo que pagaste.'
          : null;
      _errorGuardado = null;
    });
    if (_errorDescripcion != null || _errorValor != null) return;

    setState(() => _guardando = true);
    try {
      await widget.alGuardar(descripcion, valor!);
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Agregar otro costo', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        Text(
          widget.comoEstimado
              ? 'Agrega un gasto que no está en la lista (p. ej. grúa, lavado '
                    'extra). Queda como estimado; el conductor lo confirma después.'
              : 'Anota un gasto que no está en la lista (p. ej. grúa, lavado extra). '
                    'Queda guardado como real.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _descripcion,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Descripción',
            errorText: _errorDescripcion,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _valor,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          decoration: InputDecoration(
            labelText: widget.comoEstimado ? 'Valor estimado' : 'Valor pagado',
            prefixText: r'$ ',
            errorText: _errorValor,
          ),
        ),
        if (_errorGuardado != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          AppAlert(mensaje: _errorGuardado!),
        ],
        const SizedBox(height: AppSpacing.x4),
        PrimaryActionButton(
          label: 'Guardar costo',
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
