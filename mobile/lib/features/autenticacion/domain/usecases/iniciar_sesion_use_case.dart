import '../entities/sesion.dart';
import '../repositories/auth_repository.dart';

/// Inicia sesion con correo y contrasena. Devuelve la [Sesion] o lanza
/// `AuthFailure`.
class IniciarSesionUseCase {
  const IniciarSesionUseCase(this._repositorio);

  final AuthRepository _repositorio;

  Future<Sesion> call({required String correo, required String contrasena}) {
    return _repositorio.iniciarSesion(
      correo: correo.trim(),
      contrasena: contrasena,
    );
  }
}
