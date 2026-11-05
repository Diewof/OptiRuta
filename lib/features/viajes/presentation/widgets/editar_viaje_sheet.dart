import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/hoja_inferior.dart';
import '../../../../core/widgets/miles_formatter.dart';
import '../../../../core/widgets/primary_action_button.dart';

/// Hoja del administrador para editar fecha de salida, peso y flete de un
/// viaje abierto (RF-04). Origen, destino, vehículo y conductor no se editan:
/// cambiarlos invalida la ruta y el ACPM, así que se cancela y se crea otro.
class EditarViajeSheet extends StatefulWidget {
  const EditarViajeSheet({
    required this.fechaActual,
    required this.pesoActual,
    required this.fleteActual,
    required this.alGuardar,
    super.key,
  });

  final DateTime? fechaActual;
  final double? pesoActual;
  final double fleteActual;

  /// Debe lanzar [CatalogoFailure] si falla.
  final Future<void> Function(DateTime fecha, double? peso, double flete)
  alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required DateTime? fechaActual,
    required double? pesoActual,
    required double fleteActual,
    required Future<void> Function(DateTime fecha, double? peso, double flete)
    alGuardar,
  }) {
    return HojaInferior.mostrar<bool>(
      context,
      builder: (BuildContext _) => EditarViajeSheet(
        fechaActual: fechaActual,
        pesoActual: pesoActual,
        fleteActual: fleteActual,
        alGuardar: alGuardar,
      ),
    );
  }

  @override
  State<EditarViajeSheet> createState() => _EditarViajeSheetState();
}

class _EditarViajeSheetState extends State<EditarViajeSheet> {
  late DateTime _fecha = widget.fechaActual ?? DateTime.now();
  late final TextEditingController _peso = TextEditingController(
    text: widget.pesoActual == null
        ? ''
        : MilesFormatter.conMiles(widget.pesoActual!.round().toString()),
  );
  late final TextEditingController _flete = TextEditingController(
    text: widget.fleteActual > 0
        ? MilesFormatter.conMiles(widget.fleteActual.round().toString())
        : '',
  );
  bool _guardando = false;
  String? _errorFlete;
  String? _errorGuardado;

  @override
  void dispose() {
    _peso.dispose();
    _flete.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final DateTime? f = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (f != null) {
      setState(
        () => _fecha = DateTime(
          f.year,
          f.month,
          f.day,
          _fecha.hour,
          _fecha.minute,
        ),
      );
    }
  }

  Future<void> _guardar() async {
    final double? flete = double.tryParse(
      _flete.text.replaceAll(RegExp(r'\D'), ''),
    );
    final double? peso = double.tryParse(
      _peso.text.replaceAll(RegExp(r'\D'), ''),
    );
    if (flete == null || flete <= 0) {
      setState(() => _errorFlete = 'Escribe el valor del flete.');
      return;
    }
    setState(() {
      _guardando = true;
      _errorFlete = null;
      _errorGuardado = null;
    });
    try {
      await widget.alGuardar(_fecha, peso, flete);
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Editar viaje', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            'Si cambia el flete, la comisión estimada se recalcula. Para '
            'cambiar origen, destino, vehículo o conductor, cancela el viaje '
            'y crea uno nuevo.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x4),
          OutlinedButton.icon(
            onPressed: _elegirFecha,
            icon: const Icon(LucideIcons.calendar, size: 18),
            label: Text('Salida programada: ${formatearFecha(_fecha)}'),
          ),
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: _flete,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[MilesFormatter()],
            decoration: InputDecoration(
              labelText: 'Valor del flete',
              prefixText: r'$ ',
              errorText: _errorFlete,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          TextField(
            controller: _peso,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[MilesFormatter()],
            decoration: const InputDecoration(
              labelText: 'Peso de la carga (t, opcional)',
            ),
          ),
          if (_errorGuardado != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            AppAlert(mensaje: _errorGuardado!),
          ],
          const SizedBox(height: AppSpacing.x4),
          PrimaryActionButton(
            label: 'Guardar cambios',
            grande: true,
            loading: _guardando,
            onPressed: _guardar,
          ),
          const SizedBox(height: AppSpacing.x2),
          TextButton(
            onPressed: _guardando
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
