import '../repositories/auth_repository.dart';

/// Lanza el inicio de sesion con Google. La sesion resultante llega por el
/// stream de `ObservarSesionUseCase`. Lanza `AuthFailure` si no se pudo iniciar.
class IniciarConGoogleUseCase {
  const IniciarConGoogleUseCase(this._repositorio);

  final AuthRepository _repositorio;

  Future<void> call() => _repositorio.iniciarConGoogle();
}
