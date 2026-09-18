import 'package:equatable/equatable.dart';

import 'usuario.dart';

/// Sesion activa: el usuario autenticado y su perfil resuelto.
///
/// Los tokens (JWT + refresh) los administra el SDK de Supabase; el dominio
/// solo necesita saber quien es el usuario y con que rol.
class Sesion extends Equatable {
  const Sesion({required this.usuario});

  final Usuario usuario;

  @override
  List<Object?> get props => <Object?>[usuario];
}
