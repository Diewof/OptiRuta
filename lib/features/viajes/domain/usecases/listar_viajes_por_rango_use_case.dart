import '../entities/viaje_resumen.dart';
import '../repositories/viaje_repository.dart';

class ListarViajesPorRangoUseCase {
  const ListarViajesPorRangoUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<List<ViajeResumen>> call({
    required DateTime desde,
    required DateTime hasta,
  }) => _repositorio.listarPorRango(desde: desde, hasta: hasta);
}
