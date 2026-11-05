import '../entities/viaje.dart';
import '../repositories/viaje_repository.dart';

class CerrarViajeUseCase {
  const CerrarViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<Viaje> call(String viajeId) => _repositorio.cerrar(viajeId);
}
