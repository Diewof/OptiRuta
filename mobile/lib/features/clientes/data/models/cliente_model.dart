import '../../domain/entities/cliente.dart';

/// Mapea la fila de `public.cliente` (PostgREST) a la entidad de dominio y
/// construye los mapas de insercion/actualizacion.
abstract final class ClienteModel {
  static Cliente aEntidad(Map<String, dynamic> fila) {
    return Cliente(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      documento: fila['documento'] as String?,
      telefono: fila['telefono'] as String?,
      correo: fila['correo'] as String?,
      direccion: fila['direccion'] as String?,
      activo: fila['activo'] as bool,
    );
  }

  static Map<String, dynamic> aFila({
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  }) {
    return <String, dynamic>{
      'nombre': nombre,
      'documento': documento,
      'telefono': telefono,
      'correo': correo,
      'direccion': direccion,
    };
  }
}
