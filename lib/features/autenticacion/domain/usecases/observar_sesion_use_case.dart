import '../entities/sesion.dart';
import '../repositories/auth_repository.dart';

/// Observa el estado de autenticacion: emite la [Sesion] vigente o `null`.
class ObservarSesionUseCase {
  const ObservarSesionUseCase(this._repositorio);

  final AuthRepository _repositorio;

  Stream<Sesion?> call() => _repositorio.observarSesion();
}
