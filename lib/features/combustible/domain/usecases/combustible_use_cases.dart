import '../entities/rendimiento_combustible.dart';
import '../repositories/combustible_repository.dart';

class RegistrarTanqueoUseCase {
  const RegistrarTanqueoUseCase(this._repositorio);

  final CombustibleRepository _repositorio;

  Future<void> call({
    required String viajeId,
    required double galones,
    required double valor,
  }) => _repositorio.registrarTanqueo(
    viajeId: viajeId,
    galones: galones,
    valor: valor,
  );
}

class ObtenerRendimientoCombustibleUseCase {
  const ObtenerRendimientoCombustibleUseCase(this._repositorio);

  final CombustibleRepository _repositorio;

  Future<List<RendimientoCombustible>> call({
    required DateTime desde,
    required DateTime hasta,
    required DimensionCombustible dimension,
  }) => _repositorio.rendimiento(
    desde: desde,
    hasta: hasta,
    dimension: dimension,
  );
}
