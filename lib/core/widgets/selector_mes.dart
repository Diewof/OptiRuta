import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

const List<String> _mesesEs = <String>[
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Selector de mes de las pestañas del Resumen. No permite pasar del mes
/// actual.
class SelectorMes extends StatelessWidget {
  const SelectorMes({
    required this.mes,
    required this.onAnterior,
    required this.onSiguiente,
    super.key,
  });

  final DateTime mes;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final DateTime hoy = DateTime.now();
    final bool esMesActual = mes.year == hoy.year && mes.month == hoy.month;

    return Row(
      children: <Widget>[
        const Expanded(child: Text('Período', style: AppTypography.subtitle)),
        IconButton(
          onPressed: onAnterior,
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: 'Mes anterior',
          color: AppColors.primary,
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            '${_mesesEs[mes.month - 1]} ${mes.year}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: esMesActual ? null : onSiguiente,
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: 'Mes siguiente',
          color: AppColors.primary,
        ),
      ],
    );
  }
}
