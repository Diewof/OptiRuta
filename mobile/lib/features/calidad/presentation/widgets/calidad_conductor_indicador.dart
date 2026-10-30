import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/calidad.dart';
import '../../domain/usecases/calidad_use_cases.dart';
import 'nivel_calidad_badge.dart';

/// Indicador de calidad del mes de un conductor, para su perfil y para la
/// tarjeta que ve el administrador. Es informativo: sin viajes en el mes o si
/// falla la consulta no ocupa espacio ni bloquea la pantalla.
class CalidadConductorIndicador extends StatefulWidget {
  const CalidadConductorIndicador({
    required this.conductorId,
    required this.obtener,
    this.ahora,
    super.key,
  });

  final String conductorId;
  final ObtenerCalidadDeConductorUseCase obtener;

  /// Solo para pruebas: fija el «hoy» que define el mes.
  final DateTime? ahora;

  @override
  State<CalidadConductorIndicador> createState() =>
      _CalidadConductorIndicadorState();
}

class _CalidadConductorIndicadorState extends State<CalidadConductorIndicador> {
  late final Future<ResumenCalidad?> _resumen = _cargar();

  Future<ResumenCalidad?> _cargar() async {
    final DateTime hoy = widget.ahora ?? DateTime.now();
    final DateTime desde = DateTime(hoy.year, hoy.month);
    final DateTime hasta = DateTime(hoy.year, hoy.month + 1, 0);
    try {
      return await widget.obtener(widget.conductorId, desde, hasta);
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResumenCalidad?>(
      future: _resumen,
      builder: (BuildContext context, AsyncSnapshot<ResumenCalidad?> snap) {
        final ResumenCalidad? r = snap.data;
        if (r == null || r.viajesEvaluados == 0) {
          return const SizedBox.shrink();
        }
        final NivelCalidad? nivel = NivelCalidad.dePuntaje(r.puntajePromedio);

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x2),
          child: Semantics(
            container: true,
            label:
                'Calidad del mes: ${nivel.etiqueta}, puntaje '
                '${r.puntajePromedio?.round() ?? 0} de 100, '
                '${r.viajesEvaluados} viajes evaluados',
            child: ExcludeSemantics(
              child: Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Icon(
                    LucideIcons.badgeCheck,
                    size: 14,
                    color: AppColors.navy,
                  ),
                  Text('Calidad del mes', style: AppTypography.caption),
                  NivelCalidadBadge(nivel: nivel),
                  Text(
                    '${r.puntajePromedio?.round() ?? 0}/100 · '
                    '${r.viajesEvaluados} '
                    '${r.viajesEvaluados == 1 ? 'viaje' : 'viajes'}',
                    style: AppTypography.caption.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
