import '../entities/estado_viaje.dart';
import '../entities/viaje.dart';
import '../repositories/viaje_repository.dart';

class CambiarEstadoViajeUseCase {
  const CambiarEstadoViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<Viaje> call({
    required String viajeId,
    required EstadoViaje nuevoEstado,
  }) => _repositorio.cambiarEstado(viajeId: viajeId, nuevoEstado: nuevoEstado);
}
