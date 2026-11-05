import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/calidad.dart';
import '../../domain/usecases/calidad_use_cases.dart';
import 'nivel_calidad_badge.dart';

String _decimal(double valor) => valor.toStringAsFixed(1).replaceAll('.', ',');

/// Calificación automática del viaje, en su detalle (solo Administrador).
/// No hay formulario: cada dimensión sale de datos que el viaje ya tiene. Se
/// oculta si el viaje aún no está finalizado o si falla la consulta: es
/// informativa, no bloquea el detalle.
class CalidadViajeCard extends StatefulWidget {
  const CalidadViajeCard({
    required this.viajeId,
    required this.obtener,
    super.key,
  });

  final String viajeId;
  final ObtenerCalidadDeViajeUseCase obtener;

  @override
  State<CalidadViajeCard> createState() => _CalidadViajeCardState();
}

class _CalidadViajeCardState extends State<CalidadViajeCard> {
  late final Future<CalidadViaje?> _calidad = _cargar();

  Future<CalidadViaje?> _cargar() async {
    try {
      return await widget.obtener(widget.viajeId);
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CalidadViaje?>(
      future: _calidad,
      builder: (BuildContext context, AsyncSnapshot<CalidadViaje?> snap) {
        final CalidadViaje? c = snap.data;
        if (c == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x3),
          child: AppCard(
            stripe: AppCardStripe.left,
            stripeColor: c.nivel.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      LucideIcons.badgeCheck,
                      size: 18,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    const Expanded(
                      child: Text(
                        'Calidad del viaje',
                        style: AppTypography.subtitle,
                      ),
                    ),
                    NivelCalidadBadge(nivel: c.nivel),
                  ],
                ),
                if (c.puntaje != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.x1),
                    child: Text(
                      'Puntaje ${c.puntaje!.round()} de 100',
                      style: AppTypography.caption.copyWith(
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.x3),
                _FilaDimension(
                  etiqueta: 'Puntualidad',
                  nivel: c.puntualidad,
                  detalle: _detallePuntualidad(c),
                ),
                _FilaDimension(
                  etiqueta: 'Rentabilidad',
                  nivel: c.rentabilidad,
                  detalle: _detalleRentabilidad(c),
                ),
                _FilaDimension(
                  etiqueta: 'Cliente',
                  nivel: c.satisfaccion,
                  detalle: c.csatPromedio == null
                      ? 'El cliente aún no responde la encuesta'
                      : 'Calificación ${_decimal(c.csatPromedio!)} de 5',
                ),
                _FilaDimension(
                  etiqueta: 'Incidencias',
                  nivel: c.incidencias,
                  detalle: c.incidenciasTotal == 0
                      ? 'Sin alertas en ruta'
                      : '${c.incidenciasTotal} '
                            '${c.incidenciasTotal == 1 ? 'alerta' : 'alertas'} '
                            'en ruta (desvíos, paradas, pausas o checklist)',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _detallePuntualidad(CalidadViaje c) {
    final double? m = c.minutosRetraso;
    if (m == null) return 'Faltan hitos de salida y llegada';
    final int min = m.abs().round();
    if (m <= 0) {
      return min == 0
          ? 'Llegó en el tiempo estimado'
          : '$min min antes de lo estimado';
    }
    return '$min min más de lo estimado';
  }

  static String _detalleRentabilidad(CalidadViaje c) {
    final double? d = c.desvioCostosPct;
    if (d == null) return 'Sin costos estimados para comparar';
    final String base = d <= 0
        ? 'Costos dentro de lo estimado'
        : 'Costos ${_decimal(d)} % sobre lo estimado';
    final String? cat = c.categoriaMayorDesvio;
    return d > 0 && cat != null ? '$base (mayor desvío: $cat)' : base;
  }
}

class _FilaDimension extends StatelessWidget {
  const _FilaDimension({
    required this.etiqueta,
    required this.nivel,
    required this.detalle,
  });

  final String etiqueta;
  final NivelCalidad? nivel;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Semantics(
        label: '$etiqueta: ${nivel.etiqueta}. $detalle',
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(nivel.icono, size: 18, color: nivel.color),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      etiqueta,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(detalle, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
