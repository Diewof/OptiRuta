import 'package:equatable/equatable.dart';

import 'categoria_costo.dart';

/// Resultado de la RPC `rentabilidad_consolidada(p_desde, p_hasta)`: agrega
/// los viajes CERRADO del período, menos mantenimiento amortizado y sueldo
/// fijo prorrateado (fuente de datos de la Analítica del Administrador).
class RentabilidadConsolidada extends Equatable {
  const RentabilidadConsolidada({
    required this.totalFlete,
    required this.totalCostosDirectos,
    required this.mantenimientoAmortizado,
    required this.sueldoFijoProrrateado,
    required this.rentabilidadConsolidada,
    required this.viajesIncluidos,
    this.costosPorCategoria = const <CategoriaCosto, double>{},
  });

  final double totalFlete;
  final double totalCostosDirectos;
  final double mantenimientoAmortizado;
  final double sueldoFijoProrrateado;
  final double rentabilidadConsolidada;
  final int viajesIncluidos;

  /// Total de cada costo directo (ACPM, peajes, cargue...) de los viajes
  /// cerrados del período; suma [totalCostosDirectos].
  final Map<CategoriaCosto, double> costosPorCategoria;

  double get totalCostos =>
      totalCostosDirectos + mantenimientoAmortizado + sueldoFijoProrrateado;

  @override
  List<Object?> get props => <Object?>[
    totalFlete,
    totalCostosDirectos,
    mantenimientoAmortizado,
    sueldoFijoProrrateado,
    rentabilidadConsolidada,
    viajesIncluidos,
    costosPorCategoria,
  ];
}
