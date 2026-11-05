import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/rol_usuario.dart';
import '../../domain/entities/sesion.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/errores/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/usuario_model.dart';

/// Implementacion de [AuthRepository] sobre Supabase Auth + PostgREST.
///
/// Traduce todo error del proveedor a `AuthFailure` (codigo + mensaje en
/// espanol). El `rol` se toma del JWT (`app_metadata.rol`), nunca de la
/// columna editable de la tabla.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<Sesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final AuthResponse respuesta;
    try {
      respuesta = await _remote.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );
    } on AuthException catch (e) {
      throw _traducirAuthException(e);
    } on SocketException {
      throw AuthFailure.sinConexion();
    }

    final User? usuarioAuth = respuesta.user;
    if (usuarioAuth == null) {
      throw AuthFailure.credencialesInvalidas();
    }
    return _resolverSesion(usuarioAuth);
  }

  @override
  Future<void> iniciarConGoogle() async {
    final bool abierto;
    try {
      abierto = await _remote.iniciarConGoogle();
    } on AuthException catch (e) {
      throw _traducirAuthException(e);
    } on SocketException {
      throw AuthFailure.sinConexion();
    }
    if (!abierto) throw AuthFailure.desconocido();
  }

  @override
  Future<Sesion?> registrarse({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    final AuthResponse respuesta;
    try {
      respuesta = await _remote.registrarse(
        nombre: nombre,
        correo: correo,
        contrasena: contrasena,
      );
    } on AuthException catch (e) {
      throw _traducirRegistroException(e);
    } on SocketException {
      throw AuthFailure.sinConexion();
    }

    final User? usuarioAuth = respuesta.user;
    if (usuarioAuth == null) {
      throw AuthFailure.desconocido();
    }
    // Sin sesion => el proyecto exige confirmar el correo antes de entrar.
    if (respuesta.session == null) return null;

    return _resolverSesion(usuarioAuth);
  }

  @override
  Future<void> enviarRecuperacion({required String correo}) async {
    try {
      await _remote.enviarRecuperacion(correo);
    } on AuthException {
      // No revelar si el correo existe: se ignoran los errores de dominio del
      // proveedor. Un fallo de red si se propaga.
      return;
    } on SocketException {
      throw AuthFailure.sinConexion();
    }
  }

  @override
  Future<void> cerrarSesion() async {
    try {
      await _remote.cerrarSesion();
    } on AuthException catch (e) {
      throw _traducirAuthException(e);
    } on SocketException {
      throw AuthFailure.sinConexion();
    }
  }

  @override
  Future<Sesion?> sesionActual() async {
    final User? usuarioAuth = _remote.sesionActual?.user;
    if (usuarioAuth == null) return null;
    try {
      return await _resolverSesion(usuarioAuth);
    } on AuthFailure {
      return null;
    }
  }

  @override
  Stream<Sesion?> observarSesion() {
    return _remote.cambiosDeAutenticacion.asyncMap((AuthState estado) async {
      final User? usuarioAuth = estado.session?.user;
      if (usuarioAuth == null) return null;
      try {
        return await _resolverSesion(usuarioAuth);
      } catch (_) {
        // Ante cualquier fallo al resolver el perfil se trata como "sin sesion
        // valida" (denegar por defecto); nunca se propaga error crudo al Cubit.
        return null;
      }
    });
  }

  /// Construye la [Sesion] a partir del usuario de Auth: rol desde el JWT y
  /// resto del perfil desde `public.usuario`.
  Future<Sesion> _resolverSesion(User usuarioAuth) async {
    final Map<String, dynamic>? fila;
    try {
      fila = await _remote.obtenerPerfil(usuarioAuth.id);
    } on PostgrestException catch (e) {
      throw _traducirPostgrestException(e);
    } on SocketException {
      throw AuthFailure.sinConexion();
    }

    if (fila == null) {
      throw AuthFailure.perfilNoEncontrado();
    }

    // Fuente de verdad del rol: el JWT (app_metadata.rol). Si el token recien
    // emitido aun no lo trae (puede pasar justo despues del signUp), se cae en
    // la columna de la fila, que solo el servidor puede escribir.
    final RolUsuario rol;
    try {
      rol = RolUsuario.desdeCodigo(
        (usuarioAuth.appMetadata['rol'] as String?) ?? fila['rol'] as String?,
      );
    } on ArgumentError {
      throw AuthFailure.perfilNoEncontrado();
    }

    final Usuario usuario = UsuarioModel.aEntidad(fila, rol: rol);
    if (!usuario.activo) {
      await _remote.cerrarSesion();
      throw AuthFailure.usuarioInactivo();
    }

    return Sesion(usuario: usuario);
  }

  AuthFailure _traducirAuthException(AuthException e) {
    final String codigo = (e.code ?? '').toLowerCase();
    final String mensaje = e.message.toLowerCase();

    if (codigo == 'invalid_credentials' ||
        mensaje.contains('invalid login credentials')) {
      return AuthFailure.credencialesInvalidas();
    }
    if (codigo.contains('expired') || mensaje.contains('expired')) {
      return AuthFailure.sesionExpirada();
    }
    if (e is AuthRetryableFetchException) {
      return AuthFailure.sinConexion();
    }
    return AuthFailure.desconocido();
  }

  AuthFailure _traducirRegistroException(AuthException e) {
    final String codigo = (e.code ?? '').toLowerCase();
    final String mensaje = e.message.toLowerCase();

    if (codigo == 'user_already_exists' ||
        codigo == 'email_exists' ||
        mensaje.contains('already registered') ||
        mensaje.contains('already been registered')) {
      return AuthFailure.correoYaRegistrado();
    }
    if (codigo == 'weak_password' || mensaje.contains('password')) {
      return AuthFailure.contrasenaDebil();
    }
    if (e is AuthRetryableFetchException) {
      return AuthFailure.sinConexion();
    }
    return AuthFailure.desconocido();
  }

  AuthFailure _traducirPostgrestException(PostgrestException e) {
    // PGRST301 / 401: token invalido o expirado.
    if (e.code == 'PGRST301' || e.code == '401') {
      return AuthFailure.sesionExpirada();
    }
    return AuthFailure.desconocido();
  }
}
