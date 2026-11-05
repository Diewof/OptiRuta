import 'package:equatable/equatable.dart';

/// Usuario con rol CONDUCTOR que aun no tiene fila en `public.conductor`
/// (se registro por la app pero el administrador no le ha creado el perfil
/// operativo). Solo se usa para poblar el selector del alta de conductor.
class UsuarioDisponible extends Equatable {
  const UsuarioDisponible({
    required this.id,
    required this.nombre,
    required this.documento,
  });

  final String id;
  final String nombre;
  final String? documento;

  @override
  List<Object?> get props => <Object?>[id, nombre, documento];
}
