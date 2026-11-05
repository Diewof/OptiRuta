import '../../../dashboard/domain/entities/metricas.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../entities/satisfaccion.dart';
import '../repositories/satisfaccion_repository.dart';

class ObtenerResumenSatisfaccionUseCase {
  const ObtenerResumenSatisfaccionUseCase(this._repositorio);

  final SatisfaccionRepository _repositorio;

  Future<ResumenSatisfaccion> call(FiltroReporte filtro) =>
      _repositorio.resumen(filtro);
}

class ObtenerSatisfaccionPorDimensionUseCase {
  const ObtenerSatisfaccionPorDimensionUseCase(this._repositorio);

  final SatisfaccionRepository _repositorio;

  Future<List<SatisfaccionDimension>> call(
    FiltroReporte filtro,
    DimensionMetrica dimension,
  ) => _repositorio.porDimension(filtro, dimension);
}

class ObtenerEncuestaDeViajeUseCase {
  const ObtenerEncuestaDeViajeUseCase(this._repositorio);

  final SatisfaccionRepository _repositorio;

  Future<EncuestaViaje?> call(String viajeId) =>
      _repositorio.encuestaDeViaje(viajeId);
}

class ListarComentariosSatisfaccionUseCase {
  const ListarComentariosSatisfaccionUseCase(this._repositorio);

  final SatisfaccionRepository _repositorio;

  Future<List<ComentarioSatisfaccion>> call(
    FiltroReporte filtro, {
    int limite = 20,
  }) => _repositorio.comentarios(filtro, limite: limite);
}
