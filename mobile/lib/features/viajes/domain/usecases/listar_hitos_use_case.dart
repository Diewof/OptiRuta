import '../entities/hito.dart';
import '../repositories/hito_repository.dart';

class ListarHitosUseCase {
  const ListarHitosUseCase(this._repositorio);

  final HitoRepository _repositorio;

  Future<List<Hito>> call(String viajeId) =>
      _repositorio.listarPorViaje(viajeId);
}
