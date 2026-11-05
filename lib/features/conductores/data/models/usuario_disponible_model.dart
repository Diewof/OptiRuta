import '../../domain/entities/usuario_disponible.dart';

abstract final class UsuarioDisponibleModel {
  static UsuarioDisponible aEntidad(Map<String, dynamic> fila) {
    return UsuarioDisponible(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      documento: fila['documento'] as String?,
    );
  }
}
