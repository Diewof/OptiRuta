import '../entities/conductor.dart';
import '../repositories/conductor_repository.dart';

/// Perfil de conductor del propio usuario autenticado (rol CONDUCTOR).
class ObtenerMiConductorUseCase {
  const ObtenerMiConductorUseCase(this._repositorio);

  final ConductorRepository _repositorio;

  Future<Conductor?> call(String usuarioId) =>
      _repositorio.obtenerPropio(usuarioId);
}
