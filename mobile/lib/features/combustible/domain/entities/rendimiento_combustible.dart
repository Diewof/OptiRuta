import 'package:equatable/equatable.dart';

/// Por qué eje se agrupa el rendimiento de combustible.
enum DimensionCombustible {
  vehiculo('VEHICULO', 'Vehículo'),
  ruta('RUTA', 'Ruta');

  const DimensionCombustible(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

/// Una fila de `combustible_rendimiento`: km por galón real (km GPS ÷ galones
/// comprados) de una placa o ruta en el mes, contra los 3 meses anteriores.
/// [alerta] la calcula el servidor (caída del 15 % o más); la app solo la
/// muestra como «consumo anómalo».
class RendimientoCombustible extends Equatable {
  const RendimientoCombustible({
    required this.clave,
    required this.viajes,
    required this.km,
    required this.galones,
    required this.kmPorGalon,
    required this.alerta,
    this.kmPorGalonPrevio,
    this.variacionPct,
    this.referenciaKmGalon,
  });

  final String clave;
  final int viajes;
  final double km;
  final double galones;
  final double kmPorGalon;
  final double? kmPorGalonPrevio;

  /// Variación contra el histórico: negativa = consume más.
  final double? variacionPct;

  /// Rendimiento declarado del vehículo (solo por vehículo).
  final double? referenciaKmGalon;
  final bool alerta;

  @override
  List<Object?> get props => <Object?>[
    clave,
    viajes,
    km,
    galones,
    kmPorGalon,
    kmPorGalonPrevio,
    variacionPct,
    referenciaKmGalon,
    alerta,
  ];
}
