import 'package:equatable/equatable.dart';

/// Por qué eje se agrupan las métricas de rendimiento (RF-25).
enum DimensionMetrica {
  ruta('RUTA', 'Ruta'),
  cliente('CLIENTE', 'Cliente'),
  conductor('CONDUCTOR', 'Conductor'),
  placa('PLACA', 'Placa');

  const DimensionMetrica(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

/// Resultado de la RPC `metricas_periodo`: indicadores operativos de los
/// viajes cerrados del período (RF-24/25). Los km son los estimados por la
/// ruta (no se guarda distancia real).
class MetricasPeriodo extends Equatable {
  const MetricasPeriodo({
    required this.viajesCerrados,
    required this.kmTotal,
    required this.costosDirectos,
    required this.viajesATiempo,
    required this.viajesMedidos,
    required this.utilizacionFlotaPct,
    this.costoPorKm,
  });

  final int viajesCerrados;
  final double kmTotal;
  final double costosDirectos;

  /// Costos directos ÷ km; nulo si el período no tiene km.
  final double? costoPorKm;
  final int viajesATiempo;

  /// Viajes con hitos de salida y llegada y tiempo estimado: la base del
  /// cumplimiento. Si es 0 no hay cumplimiento calculable.
  final int viajesMedidos;
  final double utilizacionFlotaPct;

  /// % de viajes que llegaron dentro del tiempo estimado + margen.
  double? get cumplimientoPct =>
      viajesMedidos == 0 ? null : viajesATiempo / viajesMedidos * 100;

  @override
  List<Object?> get props => <Object?>[
    viajesCerrados,
    kmTotal,
    costosDirectos,
    costoPorKm,
    viajesATiempo,
    viajesMedidos,
    utilizacionFlotaPct,
  ];
}

/// Una fila de `metricas_por_dimension_v3`: el rendimiento de una ruta, un
/// cliente, un conductor o una placa en el período.
class MetricaDimension extends Equatable {
  const MetricaDimension({
    required this.clave,
    required this.viajes,
    required this.totalFlete,
    required this.totalCostos,
    required this.rentabilidad,
    required this.kmTotal,
    required this.viajesATiempo,
    required this.viajesMedidos,
    this.margenPromedio = 0,
    this.margenPct,
    this.bajoMargen = false,
  });

  final String clave;
  final int viajes;
  final double totalFlete;
  final double totalCostos;
  final double rentabilidad;
  final double kmTotal;
  final int viajesATiempo;
  final int viajesMedidos;

  /// Rentabilidad media por viaje y margen sobre el flete (nulo sin flete).
  final double margenPromedio;
  final double? margenPct;

  /// El servidor marca las filas con margen negativo o bajo el mínimo.
  final bool bajoMargen;

  double? get cumplimientoPct =>
      viajesMedidos == 0 ? null : viajesATiempo / viajesMedidos * 100;

  @override
  List<Object?> get props => <Object?>[
    clave,
    viajes,
    totalFlete,
    totalCostos,
    rentabilidad,
    kmTotal,
    viajesATiempo,
    viajesMedidos,
    margenPromedio,
    margenPct,
    bajoMargen,
  ];
}
