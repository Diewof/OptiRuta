import '../repositories/viaje_repository.dart';

class EstimarAcpmUseCase {
  const EstimarAcpmUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<double> call({
    required String vehiculoId,
    required double distanciaKm,
    required String ciudad,
  }) => _repositorio.estimarAcpm(
    vehiculoId: vehiculoId,
    distanciaKm: distanciaKm,
    ciudad: ciudad,
  );
}
