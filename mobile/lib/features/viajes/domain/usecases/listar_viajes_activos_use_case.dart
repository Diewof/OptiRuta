import '../entities/viaje_resumen.dart';
import '../repositories/viaje_repository.dart';

class ListarViajesActivosUseCase {
  const ListarViajesActivosUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<List<ViajeResumen>> call() => _repositorio.listarActivos();
}
