import '../entities/costo_viaje.dart';
import '../repositories/costo_viaje_repository.dart';

class ActualizarValorRealCostoUseCase {
  const ActualizarValorRealCostoUseCase(this._repositorio);

  final CostoViajeRepository _repositorio;

  Future<CostoViaje> call({
    required String costoId,
    required double valorReal,
  }) =>
      _repositorio.actualizarValorReal(costoId: costoId, valorReal: valorReal);
}
