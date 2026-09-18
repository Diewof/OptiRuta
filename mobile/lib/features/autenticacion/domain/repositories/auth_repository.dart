import '../entities/sesion.dart';

/// Contrato de autenticacion para la capa de dominio. La implementacion vive
/// en `data` y se apoya en Supabase Auth; los casos de uso solo conocen esta
/// interfaz.
///
/// Todos los metodos que fallan lanzan `AuthFailure` (nunca el error crudo del
/// proveedor).
abstract interface class AuthRepository {
  /// Inicia sesion con correo y contrasena y resuelve el perfil del usuario.
  Future<Sesion> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  /// Registra una cuenta nueva (siempre rol CONDUCTOR; el rol lo fija el
  /// servidor). Devuelve la [Sesion] si el proveedor entrega sesion inmediata,
  /// o `null` si queda pendiente de confirmacion por correo.
  Future<Sesion?> registrarse({
    required String nombre,
    required String correo,
    required String contrasena,
  });

  /// Envia el correo de recuperacion de contrasena. No revela si el correo
  /// existe (no lanza por "usuario no encontrado").
  Future<void> enviarRecuperacion({required String correo});

  /// Cierra la sesion y revoca el refresh token.
  Future<void> cerrarSesion();

  /// Sesion actual persistida por el SDK, o `null` si no hay ninguna.
  Future<Sesion?> sesionActual();

  /// Emite la sesion vigente ante cada cambio de estado de autenticacion
  /// (login, logout, refresh, expiracion). Emite `null` cuando no hay sesion.
  Stream<Sesion?> observarSesion();
}
