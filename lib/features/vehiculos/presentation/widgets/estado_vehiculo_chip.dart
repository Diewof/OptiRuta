import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/estado_vehiculo.dart';
import '../../domain/repositories/hoja_vida_repository.dart';
import '../bloc/estado_vehiculo_cubit.dart';

/// Semáforo de un vehículo en la lista de Flota: «Al día», o el peor problema
/// con el resto como texto. Carga su propia hoja de vida.
class EstadoVehiculoChip extends StatelessWidget {
  const EstadoVehiculoChip({required this.vehiculoId, super.key});

  final String vehiculoId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EstadoVehiculoCubit>(
      create: (BuildContext context) => EstadoVehiculoCubit(
        hojaVida: context.read<HojaVidaRepository>(),
        vehiculoId: vehiculoId,
      ),
      child: BlocBuilder<EstadoVehiculoCubit, EstadoVehiculo?>(
        builder: (BuildContext context, EstadoVehiculo? estado) {
          if (estado == null) return const SizedBox.shrink();
          final (String etiqueta, StatusTone tono) = switch (estado.nivel) {
            NivelEstadoVehiculo.alDia => ('Al día', StatusTone.success),
            NivelEstadoVehiculo.aviso => ('Por atender', StatusTone.warning),
            NivelEstadoVehiculo.critico => (
              'Requiere acción',
              StatusTone.error,
            ),
          };
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x1,
              children: <Widget>[
                StatusBadge(label: etiqueta, tone: tono),
                if (estado.motivos.isNotEmpty)
                  Text(
                    estado.motivos.take(2).join(' · '),
                    style: AppTypography.caption,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
