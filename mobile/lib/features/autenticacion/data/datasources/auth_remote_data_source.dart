import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el `GoTrueClient` de Supabase y la lectura del perfil por
/// PostgREST. No traduce errores ni conoce entidades de dominio: eso es
/// responsabilidad del repositorio.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Session? get sesionActual => _auth.currentSession;

  /// Cambios de estado de autenticacion (login, logout, refresh, expiracion).
  Stream<AuthState> get cambiosDeAutenticacion => _auth.onAuthStateChange;

  Future<AuthResponse> iniciarSesion({
    required String correo,
    required String contrasena,
  }) {
    return _auth.signInWithPassword(email: correo, password: contrasena);
  }

  /// El `data` va a `raw_user_meta_data`; el trigger del servidor toma de ahi
  /// el nombre e ignora cualquier `rol` (siempre asigna CONDUCTOR).
  Future<AuthResponse> registrarse({
    required String nombre,
    required String correo,
    required String contrasena,
  }) {
    return _auth.signUp(
      email: correo,
      password: contrasena,
      data: <String, dynamic>{'nombre': nombre},
    );
  }

  Future<void> enviarRecuperacion(String correo) =>
      _auth.resetPasswordForEmail(correo);

  Future<void> cerrarSesion() => _auth.signOut();

  /// Fila de `public.usuario` del usuario dado, o `null` si no existe.
  /// RLS garantiza que solo se pueda leer el propio perfil (o todos, si es
  /// administrador).
  Future<Map<String, dynamic>?> obtenerPerfil(String usuarioId) {
    return _client
        .from('usuario')
        .select('id, nombre, documento, activo, rol')
        .eq('id', usuarioId)
        .maybeSingle();
  }
}
