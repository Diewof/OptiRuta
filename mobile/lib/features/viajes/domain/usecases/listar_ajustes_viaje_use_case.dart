import '../entities/ajuste_viaje.dart';
import '../repositories/ajuste_viaje_repository.dart';

class ListarAjustesViajeUseCase {
  const ListarAjustesViajeUseCase(this._repositorio);

  final AjusteViajeRepository _repositorio;

  Future<List<AjusteViaje>> call(String viajeId) =>
      _repositorio.listarPorViaje(viajeId);
}
