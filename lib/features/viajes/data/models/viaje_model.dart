import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje.dart';

/// Mapea una fila de `public.viaje` (tal como la devuelven `viaje_crear`,
/// `viaje_cambiar_estado` y `viaje_cerrar`) a la entidad de dominio.
abstract final class ViajeModel {
  static Viaje aEntidad(Map<String, dynamic> fila) {
    return Viaje(
      id: fila['id'] as String,
      remision: fila['remision'] as String,
      vehiculoId: fila['vehiculo_id'] as String,
      conductorId: fila['conductor_id'] as String,
      clienteId: fila['cliente_id'] as String,
      origen: fila['origen'] as String,
      destino: fila['destino'] as String,
      fechaSalidaProgramada: fila['fecha_salida_programada'] == null
          ? null
          : DateTime.parse(fila['fecha_salida_programada'] as String).toLocal(),
      distanciaEstimada: (fila['distancia_estimada'] as num?)?.toDouble(),
      tiempoEstimadoMin: (fila['tiempo_estimado_min'] as num?)?.toDouble(),
      pesoCarga: (fila['peso_carga'] as num?)?.toDouble(),
      estado: EstadoViaje.desdeCodigo(fila['estado'] as String),
      valorFlete: (fila['valor_flete'] as num).toDouble(),
      valorAnticipo: (fila['valor_anticipo'] as num).toDouble(),
      saldoPendiente: (fila['saldo_pendiente'] as num).toDouble(),
      fechaCierre: fila['fecha_cierre'] == null
          ? null
          : DateTime.parse(fila['fecha_cierre'] as String).toLocal(),
      fechaCreacion: DateTime.parse(fila['fecha_creacion'] as String).toLocal(),
    );
  }
}
