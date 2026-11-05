import 'package:equatable/equatable.dart';

import 'rol_usuario.dart';

/// Usuario autenticado, con los datos de negocio de su perfil.
///
/// Independiente de Flutter y de la fuente de datos. El [rol] proviene del JWT
/// (`app_metadata.rol`), no de la columna editable de la tabla.
class Usuario extends Equatable {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.activo,
    this.documento,
  });

  final String id;
  final String nombre;
  final String? documento;
  final RolUsuario rol;
  final bool activo;

  bool get esAdministrador => rol == RolUsuario.administrador;
  bool get esConductor => rol == RolUsuario.conductor;

  @override
  List<Object?> get props => <Object?>[id, nombre, documento, rol, activo];
}
