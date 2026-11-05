import '../../domain/entities/rol_usuario.dart';
import '../../domain/entities/usuario.dart';

/// Mapea la fila de `public.usuario` (PostgREST) a la entidad de dominio.
///
/// El `rol` NO se toma de esta fila sino del JWT (`app_metadata.rol`), que es
/// la fuente de verdad y no es editable por el cliente. Por eso [aEntidad]
/// recibe el rol ya resuelto desde la sesion.
abstract final class UsuarioModel {
  static Usuario aEntidad(
    Map<String, dynamic> fila, {
    required RolUsuario rol,
  }) {
    return Usuario(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      documento: fila['documento'] as String?,
      activo: fila['activo'] as bool? ?? true,
      rol: rol,
    );
  }
}
