import '../../../viajes/domain/entities/coordenada.dart';
import '../../domain/entities/notificacion.dart';
import '../../domain/entities/tipo_notificacion.dart';

/// Mapea una fila de `public.notificacion` a la entidad de dominio.
abstract final class NotificacionModel {
  static Notificacion aEntidad(Map<String, dynamic> fila) {
    return Notificacion(
      id: fila['id'] as String,
      tipo: TipoNotificacion.desdeCodigo(fila['tipo'] as String),
      titulo: fila['titulo'] as String,
      mensaje: fila['mensaje'] as String,
      leida: fila['leida'] as bool,
      fechaCreacion: DateTime.parse(fila['fecha_creacion'] as String),
      viajeId: fila['viaje_id'] as String?,
      vehiculoId: fila['vehiculo_id'] as String?,
      ubicacion: fila['lat'] == null || fila['lng'] == null
          ? null
          : Coordenada(
              (fila['lat'] as num).toDouble(),
              (fila['lng'] as num).toDouble(),
            ),
    );
  }
}
