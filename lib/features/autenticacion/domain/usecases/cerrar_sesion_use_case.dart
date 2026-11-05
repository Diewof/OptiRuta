import '../repositories/auth_repository.dart';

/// Cierra la sesion activa (revoca el refresh token via Supabase Auth).
class CerrarSesionUseCase {
  const CerrarSesionUseCase(this._repositorio);

  final AuthRepository _repositorio;

  Future<void> call() => _repositorio.cerrarSesion();
}
