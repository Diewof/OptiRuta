import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/estado_viaje_badge.dart';
import '../../../../core/widgets/vehiculo_thumb.dart';
import '../../domain/entities/viaje_resumen.dart';

/// Tarjeta de viaje reutilizada en Calendario, Seguimiento e Historial:
/// miniatura del vehículo, hora + ruta, badge del ciclo del viaje y
/// cliente/vehículo/conductor.
///
/// La franja lateral indica **retraso** (RF-20), no estado ni rentabilidad:
/// ámbar si [conRetraso], neutra si no.
class ViajeResumenCard extends StatelessWidget {
  const ViajeResumenCard({
    required this.viaje,
    this.onTap,
    this.pie,
    this.conRetraso = false,
    super.key,
  });

  final ViajeResumen viaje;
  final VoidCallback? onTap;

  /// Contenido opcional bajo los datos del viaje (p. ej. la rentabilidad en
  /// Historial), dentro de la misma tarjeta en vez de anidar otra.
  final Widget? pie;

  final bool conRetraso;

  @override
  Widget build(BuildContext context) {
    final String hora = viaje.fechaSalidaProgramada == null
        ? ''
        : '${viaje.fechaSalidaProgramada!.hour.toString().padLeft(2, '0')}:'
              '${viaje.fechaSalidaProgramada!.minute.toString().padLeft(2, '0')} · ';

    return AppCard(
      stripe: AppCardStripe.left,
      stripeColor: conRetraso ? AppColors.warning : AppColors.navyTint12,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (viaje.tipoVehiculo != null) ...<Widget>[
                  VehiculoThumb(tipo: viaje.tipoVehiculo!, ancho: 64),
                  const SizedBox(width: AppSpacing.x3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$hora${viaje.origen} → ${viaje.destino}',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        '${viaje.nombreCliente} · ${viaje.placaVehiculo} · '
                        '${viaje.nombreConductor}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                EstadoViajeBadge(estado: viaje.estado, compacto: true),
              ],
            ),
            if (pie != null) ...<Widget>[
              const SizedBox(height: AppSpacing.x2),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.x2),
              pie!,
            ],
          ],
        ),
      ),
    );
  }
}
