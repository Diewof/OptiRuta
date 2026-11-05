import '../repositories/cliente_repository.dart';

class InhabilitarClienteUseCase {
  const InhabilitarClienteUseCase(this._repositorio);

  final ClienteRepository _repositorio;

  Future<void> call(String id) => _repositorio.inhabilitar(id);
}
