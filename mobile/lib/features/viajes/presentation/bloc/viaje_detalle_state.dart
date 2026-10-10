import 'package:equatable/equatable.dart';

import '../../domain/entities/ajuste_viaje.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/rentabilidad_marginal.dart';
import '../../domain/entities/viaje_resumen.dart';

sealed class ViajeDetalleState extends Equatable {
  const ViajeDetalleState();

  @override
  List<Object?> get props => <Object?>[];
}

class ViajeDetalleCargando extends ViajeDetalleState {
  const ViajeDetalleCargando();
}

class ViajeDetalleError extends ViajeDetalleState {
  const ViajeDetalleError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class ViajeDetalleListo extends ViajeDetalleState {
  const ViajeDetalleListo({
    required this.viaje,
    required this.estado,
    required this.hitos,
    required this.costos,
    required this.marginal,
    required this.ajustes,
    this.procesando = false,
  });

  final ViajeResumen viaje;

  /// Estado vigente: arranca con el del listado y cambia al cerrar.
  final EstadoViaje estado;
  final List<Hito> hitos;
  final List<CostoViaje> costos;

  /// Rentabilidad **marginal** (la consolidada vive en Resumen).
  final RentabilidadMarginal marginal;
  final List<AjusteViaje> ajustes;
  final bool procesando;

  ViajeDetalleListo copiarCon({bool? procesando}) => ViajeDetalleListo(
    viaje: viaje,
    estado: estado,
    hitos: hitos,
    costos: costos,
    marginal: marginal,
    ajustes: ajustes,
    procesando: procesando ?? this.procesando,
  );

  @override
  List<Object?> get props => <Object?>[
    viaje,
    estado,
    hitos,
    costos,
    marginal,
    ajustes,
    procesando,
  ];
}
