import '../../domain/entities/rentabilidad_consolidada.dart';
import '../../domain/entities/rentabilidad_marginal.dart';

abstract final class RentabilidadModel {
  static RentabilidadMarginal marginalDesdeFila(Map<String, dynamic> fila) {
    return RentabilidadMarginal(
      valorFlete: (fila['valor_flete'] as num).toDouble(),
      costosTotales: (fila['costos_totales'] as num).toDouble(),
      rentabilidad: (fila['rentabilidad'] as num).toDouble(),
    );
  }

  static RentabilidadConsolidada consolidadaDesdeFila(
    Map<String, dynamic> fila,
  ) {
    return RentabilidadConsolidada(
      totalFlete: (fila['total_flete'] as num).toDouble(),
      totalCostosDirectos: (fila['total_costos_directos'] as num).toDouble(),
      mantenimientoAmortizado: (fila['mantenimiento_amortizado'] as num)
          .toDouble(),
      sueldoFijoProrrateado: (fila['sueldo_fijo_prorrateado'] as num)
          .toDouble(),
      rentabilidadConsolidada: (fila['rentabilidad_consolidada'] as num)
          .toDouble(),
      viajesIncluidos: fila['viajes_incluidos'] as int,
    );
  }
}
