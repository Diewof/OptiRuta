import '../entities/metricas.dart';
import '../repositories/metricas_repository.dart';

class ObtenerMetricasPeriodoUseCase {
  const ObtenerMetricasPeriodoUseCase(this._repositorio);

  final MetricasRepository _repositorio;

  Future<MetricasPeriodo> call({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) => _repositorio.periodo(
    desde: desde,
    hasta: hasta,
    clienteId: clienteId,
    conductorId: conductorId,
    vehiculoId: vehiculoId,
    ruta: ruta,
  );
}

class ObtenerMetricasPorDimensionUseCase {
  const ObtenerMetricasPorDimensionUseCase(this._repositorio);

  final MetricasRepository _repositorio;

  Future<List<MetricaDimension>> call({
    required DateTime desde,
    required DateTime hasta,
    required DimensionMetrica dimension,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) => _repositorio.porDimension(
    desde: desde,
    hasta: hasta,
    dimension: dimension,
    clienteId: clienteId,
    conductorId: conductorId,
    vehiculoId: vehiculoId,
    ruta: ruta,
  );
}
