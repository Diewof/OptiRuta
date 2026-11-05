import '../entities/sesion.dart';
import '../repositories/auth_repository.dart';

/// Registra una cuenta nueva (rol CONDUCTOR, fijado por el servidor).
/// Devuelve la [Sesion] si hay entrada inmediata, o `null` si queda pendiente
/// de confirmacion por correo.
class RegistrarseUseCase {
  const RegistrarseUseCase(this._repositorio);

  final AuthRepository _repositorio;

  Future<Sesion?> call({
    required String nombre,
    required String correo,
    required String contrasena,
  }) {
    return _repositorio.registrarse(
      nombre: nombre.trim(),
      correo: correo.trim(),
      contrasena: contrasena,
    );
  }
}
