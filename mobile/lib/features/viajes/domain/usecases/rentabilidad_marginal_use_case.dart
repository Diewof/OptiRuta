import '../entities/rentabilidad_marginal.dart';
import '../repositories/rentabilidad_repository.dart';

class RentabilidadMarginalUseCase {
  const RentabilidadMarginalUseCase(this._repositorio);

  final RentabilidadRepository _repositorio;

  Future<RentabilidadMarginal> call(String viajeId) =>
      _repositorio.marginal(viajeId);
}
