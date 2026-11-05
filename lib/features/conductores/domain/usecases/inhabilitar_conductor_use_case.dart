import '../repositories/conductor_repository.dart';

class InhabilitarConductorUseCase {
  const InhabilitarConductorUseCase(this._repositorio);

  final ConductorRepository _repositorio;

  Future<void> call(String id) => _repositorio.inhabilitar(id);
}
