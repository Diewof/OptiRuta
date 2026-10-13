import '../entities/metricas.dart';

/// Contrato sobre las RPC `metricas_periodo` y `metricas_por_dimension`
/// (solo ADMINISTRADOR; lo exige la propia RPC).
abstract interface class MetricasRepository {
  Future<MetricasPeriodo> periodo({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  });

  Future<List<MetricaDimension>> porDimension({
    required DateTime desde,
    required DateTime hasta,
    required DimensionMetrica dimension,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  });
}
