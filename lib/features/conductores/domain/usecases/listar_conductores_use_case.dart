import '../repositories/conductor_repository.dart';

class ListarConductoresUseCase {
  const ListarConductoresUseCase(this._repositorio);

  final ConductorRepository _repositorio;

  Future<PaginaConductores> call({required int pagina, int tamano = 20}) {
    return _repositorio.listar(pagina: pagina, tamano: tamano);
  }
}
