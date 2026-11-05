import '../entities/costo_viaje.dart';
import '../repositories/costo_viaje_repository.dart';

class ActualizarEstimadoCostoUseCase {
  const ActualizarEstimadoCostoUseCase(this._repositorio);

  final CostoViajeRepository _repositorio;

  Future<CostoViaje> call({
    required String costoId,
    required double valorEstimado,
  }) {
    if (valorEstimado < 0) {
      throw ArgumentError.value(
        valorEstimado,
        'valorEstimado',
        'Debe ser >= 0.',
      );
    }
    return _repositorio.actualizarEstimado(
      costoId: costoId,
      valorEstimado: valorEstimado,
    );
  }
}
