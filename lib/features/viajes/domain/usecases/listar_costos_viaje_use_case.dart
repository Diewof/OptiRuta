import '../entities/costo_viaje.dart';
import '../repositories/costo_viaje_repository.dart';

class ListarCostosViajeUseCase {
  const ListarCostosViajeUseCase(this._repositorio);

  final CostoViajeRepository _repositorio;

  Future<List<CostoViaje>> call(String viajeId) =>
      _repositorio.listarPorViaje(viajeId);
}
