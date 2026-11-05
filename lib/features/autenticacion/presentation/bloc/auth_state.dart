import 'package:equatable/equatable.dart';

import '../../domain/entities/usuario.dart';
import '../../domain/errores/auth_failure.dart';

/// Estados del flujo de autenticacion.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => <Object?>[];
}

/// Estado inicial: aun no se sabe si hay sesion (se esta consultando el SDK).
class AuthDesconocido extends AuthState {
  const AuthDesconocido();
}

/// Operacion de inicio de sesion en curso.
class AuthAutenticando extends AuthState {
  const AuthAutenticando();
}

/// Hay sesion valida y perfil resuelto.
class AuthAutenticado extends AuthState {
  const AuthAutenticado(this.usuario);

  final Usuario usuario;

  @override
  List<Object?> get props => <Object?>[usuario];
}

/// No hay sesion: se debe mostrar el login.
class AuthNoAutenticado extends AuthState {
  const AuthNoAutenticado();
}

/// Fallo una operacion de autenticacion. La UI muestra [mensaje]; el flujo
/// sigue en el login.
class AuthError extends AuthState {
  const AuthError(this.codigo, this.mensaje);

  factory AuthError.desde(AuthFailure falla) =>
      AuthError(falla.codigo.codigo, falla.mensaje);

  final String codigo;
  final String mensaje;

  @override
  List<Object?> get props => <Object?>[codigo, mensaje];
}
