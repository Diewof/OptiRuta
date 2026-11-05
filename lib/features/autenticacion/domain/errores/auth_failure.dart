import 'package:equatable/equatable.dart';

/// Codigos de error de dominio de autenticacion. Se traducen a mensaje en
/// espanol; nunca se expone el error crudo del proveedor.
enum AuthErrorCodigo {
  credencialesInvalidas('CREDENCIALES_INVALIDAS'),
  sesionExpirada('SESION_EXPIRADA'),
  sinConexion('SIN_CONEXION'),
  perfilNoEncontrado('PERFIL_NO_ENCONTRADO'),
  usuarioInactivo('USUARIO_INACTIVO'),
  correoYaRegistrado('CORREO_YA_REGISTRADO'),
  contrasenaDebil('CONTRASENA_DEBIL'),
  desconocido('DESCONOCIDO');

  const AuthErrorCodigo(this.codigo);

  final String codigo;
}

/// Falla de dominio de autenticacion: un codigo estable y un mensaje ya
/// traducido para mostrar al usuario.
class AuthFailure extends Equatable implements Exception {
  const AuthFailure(this.codigo, this.mensaje);

  factory AuthFailure.credencialesInvalidas() => const AuthFailure(
    AuthErrorCodigo.credencialesInvalidas,
    'Correo o contraseña incorrectos.',
  );

  factory AuthFailure.sesionExpirada() => const AuthFailure(
    AuthErrorCodigo.sesionExpirada,
    'Tu sesión expiró. Inicia sesión de nuevo.',
  );

  factory AuthFailure.sinConexion() => const AuthFailure(
    AuthErrorCodigo.sinConexion,
    'Sin conexión. Revisa tu internet e intenta de nuevo.',
  );

  factory AuthFailure.perfilNoEncontrado() => const AuthFailure(
    AuthErrorCodigo.perfilNoEncontrado,
    'Tu cuenta no tiene un perfil asignado. Contacta al administrador.',
  );

  factory AuthFailure.usuarioInactivo() => const AuthFailure(
    AuthErrorCodigo.usuarioInactivo,
    'Tu cuenta está inactiva. Contacta al administrador.',
  );

  factory AuthFailure.correoYaRegistrado() => const AuthFailure(
    AuthErrorCodigo.correoYaRegistrado,
    'Ya existe una cuenta con ese correo.',
  );

  factory AuthFailure.contrasenaDebil() => const AuthFailure(
    AuthErrorCodigo.contrasenaDebil,
    'La contraseña es muy débil. Usa al menos 8 caracteres con mayúscula, minúscula y número.',
  );

  factory AuthFailure.desconocido() => const AuthFailure(
    AuthErrorCodigo.desconocido,
    'No se pudo completar la operación. Intenta más tarde.',
  );

  final AuthErrorCodigo codigo;
  final String mensaje;

  @override
  List<Object?> get props => <Object?>[codigo, mensaje];

  @override
  String toString() => 'AuthFailure(${codigo.codigo}): $mensaje';
}
