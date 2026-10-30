import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/miles_formatter.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Hoja para registrar un tanqueo del viaje en curso: galones comprados y lo
/// pagado. El servidor suma el valor al ACPM real del viaje y usa los galones
/// para calcular el rendimiento.
class TanqueoSheet extends StatefulWidget {
  const TanqueoSheet({required this.alGuardar, super.key});

  /// Guarda el tanqueo. Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function(double galones, double valor) alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required Future<void> Function(double galones, double valor) alGuardar,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => TanqueoSheet(alGuardar: alGuardar),
    );
  }

  @override
  State<TanqueoSheet> createState() => _TanqueoSheetState();
}

class _TanqueoSheetState extends State<TanqueoSheet> {
  final TextEditingController _galones = TextEditingController();
  final TextEditingController _valor = TextEditingController();
  bool _guardando = false;
  String? _errorGalones;
  String? _errorValor;
  String? _errorGuardado;

  @override
  void dispose() {
    _galones.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final double? galones = double.tryParse(_galones.text.replaceAll(',', '.'));
    final double? valor = double.tryParse(
      _valor.text.replaceAll(RegExp(r'\D'), ''),
    );
    setState(() {
      _errorGalones = galones == null || galones <= 0
          ? 'Escribe los galones que tanqueaste.'
          : null;
      _errorValor = valor == null || valor <= 0
          ? 'Escribe lo que pagaste.'
          : null;
      _errorGuardado = null;
    });
    if (_errorGalones != null || _errorValor != null) return;

    setState(() => _guardando = true);
    try {
      await widget.alGuardar(galones!, valor!);
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
        const Text('Registrar tanqueo', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'Anota cada vez que tanqueas. El valor se suma al ACPM real del '
          'viaje y los galones sirven para medir el rendimiento.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _galones,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Galones',
            suffixText: 'gal',
            errorText: _errorGalones,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _valor,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[MilesFormatter()],
          decoration: InputDecoration(
            labelText: 'Valor pagado',
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
          label: 'Guardar tanqueo',
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
