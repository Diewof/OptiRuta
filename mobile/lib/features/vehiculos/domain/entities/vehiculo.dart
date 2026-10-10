import 'package:equatable/equatable.dart';

import 'tipo_vehiculo.dart';

/// Vehiculo de la flota. Sin borrado fisico: la baja se hace con
/// `activo = false` (FK de `viaje` con `ON DELETE RESTRICT`).
class Vehiculo extends Equatable {
  const Vehiculo({
    required this.id,
    required this.placa,
    required this.tipo,
    required this.capacidadCarga,
    required this.rendimientoKmGalon,
    required this.activo,
  });

  final String id;
  final String placa;
  final TipoVehiculo tipo;

  /// Toneladas.
  final double capacidadCarga;
  final double rendimientoKmGalon;
  final bool activo;

  @override
  List<Object?> get props => <Object?>[
    id,
    placa,
    tipo,
    capacidadCarga,
    rendimientoKmGalon,
    activo,
  ];
}
