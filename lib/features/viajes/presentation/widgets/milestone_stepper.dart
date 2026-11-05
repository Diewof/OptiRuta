import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';

/// Timeline de los 4 hitos de un viaje (Salida, Cargue, Con carga, Destino):
/// verde con check si ya ocurrió, navy resaltado el siguiente esperado, gris
/// el resto. Los hitos los registra el conductor; esta app solo los lee.
class MilestoneStepper extends StatelessWidget {
  const MilestoneStepper({required this.hitos, super.key});

  final List<Hito> hitos;

  static const List<(TipoHito, String)> _pasos = <(TipoHito, String)>[
    (TipoHito.salida, 'Salida'),
    (TipoHito.llegadaCargue, 'Cargue'),
    (TipoHito.salidaConCarga, 'Con carga'),
    (TipoHito.llegadaDestino, 'Destino'),
  ];

  bool _completo(TipoHito tipo) => hitos.any((Hito h) => h.tipo == tipo);

  @override
  Widget build(BuildContext context) {
    final int indiceActual = _pasos.indexWhere(
      ((TipoHito, String) p) => !_completo(p.$1),
    );

    return Semantics(
      label: _resumenAccesible(indiceActual),
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            for (int i = 0; i < _pasos.length; i++) ...<Widget>[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    color:
                        i <= (indiceActual == -1 ? _pasos.length : indiceActual)
                        ? AppColors.success
                        : AppColors.dividerTable,
                  ),
                ),
              _Paso(
                etiqueta: _pasos[i].$2,
                estado: _estadoPaso(i, indiceActual),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EstadoPaso _estadoPaso(int i, int indiceActual) {
    if (indiceActual == -1 || i < indiceActual) return _EstadoPaso.completo;
    if (i == indiceActual) return _EstadoPaso.actual;
    return _EstadoPaso.pendiente;
  }

  String _resumenAccesible(int indiceActual) {
    if (indiceActual == -1) return 'Hitos: viaje completó los 4 hitos.';
    final String actual = _pasos[indiceActual].$2;
    return 'Hitos: $indiceActual de ${_pasos.length} completados, siguiente $actual.';
  }
}

enum _EstadoPaso { completo, actual, pendiente }

class _Paso extends StatelessWidget {
  const _Paso({required this.etiqueta, required this.estado});

  final String etiqueta;
  final _EstadoPaso estado;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (estado) {
      _EstadoPaso.completo => AppColors.success,
      _EstadoPaso.actual => AppColors.navy,
      _EstadoPaso.pendiente => AppColors.borderInput,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: estado == _EstadoPaso.completo ? color : AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: switch (estado) {
            _EstadoPaso.completo => const Icon(
              LucideIcons.check,
              size: 12,
              color: AppColors.onNavy,
            ),
            _EstadoPaso.actual => Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
            ),
            _EstadoPaso.pendiente => null,
          },
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: AppTypography.caption.copyWith(
            color: estado == _EstadoPaso.pendiente
                ? AppColors.textSecondary
                : AppColors.textPrimary,
            fontWeight: estado == _EstadoPaso.actual
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
