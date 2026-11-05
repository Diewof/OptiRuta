import '../repositories/cliente_repository.dart';

class ListarClientesUseCase {
  const ListarClientesUseCase(this._repositorio);

  final ClienteRepository _repositorio;

  Future<PaginaClientes> call({required int pagina, int tamano = 20}) {
    return _repositorio.listar(pagina: pagina, tamano: tamano);
  }
}
