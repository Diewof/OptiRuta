import '../entities/usuario_disponible.dart';
import '../repositories/conductor_repository.dart';

class ListarUsuariosDisponiblesUseCase {
  const ListarUsuariosDisponiblesUseCase(this._repositorio);

  final ConductorRepository _repositorio;

  Future<List<UsuarioDisponible>> call() =>
      _repositorio.listarUsuariosDisponibles();
}
