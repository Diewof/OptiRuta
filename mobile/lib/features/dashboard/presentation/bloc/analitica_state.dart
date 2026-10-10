import 'package:equatable/equatable.dart';

import '../../../viajes/domain/entities/rentabilidad_consolidada.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';

sealed class AnaliticaState extends Equatable {
  const AnaliticaState();

  @override
  List<Object?> get props => <Object?>[];
}

class AnaliticaCargando extends AnaliticaState {
  const AnaliticaCargando();
}

class AnaliticaError extends AnaliticaState {
  const AnaliticaError(this.mensaje);

  final String mensaje;

  @override
  List<Object?> get props => <Object?>[mensaje];
}

class AnaliticaListo extends AnaliticaState {
  const AnaliticaListo({
    required this.mes,
    required this.rentabilidad,
    required this.vehiculosEnRuta,
    required this.vehiculosDisponibles,
    required this.totalVehiculosActivos,
    this.viajesActivos = const <ViajeResumen>[],
  });

  /// Primer día del mes mostrado.
  final DateTime mes;
  final RentabilidadConsolidada rentabilidad;
  final int vehiculosEnRuta;
  final int vehiculosDisponibles;
  final int totalVehiculosActivos;

  /// Viajes ASIGNADO/EN_CURSO (los mismos con los que se calcula la flota).
  final List<ViajeResumen> viajesActivos;

  @override
  List<Object?> get props => <Object?>[
    mes,
    rentabilidad,
    vehiculosEnRuta,
    vehiculosDisponibles,
    totalVehiculosActivos,
    viajesActivos,
  ];
}
