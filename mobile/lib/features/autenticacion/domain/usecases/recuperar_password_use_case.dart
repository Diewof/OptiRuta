import '../repositories/auth_repository.dart';

/// Envia el correo de recuperacion de contrasena.
class RecuperarPasswordUseCase {
  const RecuperarPasswordUseCase(this._repositorio);

  final AuthRepository _repositorio;

  Future<void> call({required String correo}) {
    return _repositorio.enviarRecuperacion(correo: correo.trim());
  }
}
