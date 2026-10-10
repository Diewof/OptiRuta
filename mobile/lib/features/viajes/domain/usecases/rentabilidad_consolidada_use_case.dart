import '../entities/rentabilidad_consolidada.dart';
import '../repositories/rentabilidad_repository.dart';

class RentabilidadConsolidadaUseCase {
  const RentabilidadConsolidadaUseCase(this._repositorio);

  final RentabilidadRepository _repositorio;

  Future<RentabilidadConsolidada> call({
    required DateTime desde,
    required DateTime hasta,
  }) => _repositorio.consolidada(desde: desde, hasta: hasta);
}
