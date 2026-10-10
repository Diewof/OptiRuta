import '../repositories/vehiculo_repository.dart';

class InhabilitarVehiculoUseCase {
  const InhabilitarVehiculoUseCase(this._repositorio);

  final VehiculoRepository _repositorio;

  Future<void> call(String id) => _repositorio.inhabilitar(id);
}
