import '../../domain/entities/categoria_costo.dart';
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
      costosPorCategoria: _costosPorCategoria(fila['costos_por_categoria']),
    );
  }

  /// `{"ACPM": 250000, ...}` → mapa por categoría; una categoría desconocida
  /// se ignora para que un tipo nuevo no tumbe el Resumen.
  static Map<CategoriaCosto, double> _costosPorCategoria(Object? crudo) {
    if (crudo is! Map) return const <CategoriaCosto, double>{};
    final Map<CategoriaCosto, double> salida = <CategoriaCosto, double>{};
    crudo.forEach((Object? clave, Object? valor) {
      try {
        salida[CategoriaCosto.desdeCodigo(clave as String)] = (valor as num)
            .toDouble();
      } on ArgumentError {
        // Categoría que esta versión de la app no conoce.
      }
    });
    return salida;
  }
}
