import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';

/// Mapea una fila de `public.viaje` con sus embeds de PostgREST
/// (`vehiculo:vehiculo_id(placa, tipo)`,
/// `conductor:conductor_id(usuario:usuario_id(nombre))`,
/// `cliente:cliente_id(nombre)`) a la entidad de listado.
abstract final class ViajeResumenModel {
  static ViajeResumen aEntidad(Map<String, dynamic> fila) {
    final Map<String, dynamic> vehiculo =
        fila['vehiculo'] as Map<String, dynamic>;
    final Map<String, dynamic> conductor =
        fila['conductor'] as Map<String, dynamic>;
    final Map<String, dynamic> usuarioConductor =
        conductor['usuario'] as Map<String, dynamic>;
    final Map<String, dynamic> cliente =
        fila['cliente'] as Map<String, dynamic>;

    return ViajeResumen(
      id: fila['id'] as String,
      remision: fila['remision'] as String,
      origen: fila['origen'] as String,
      destino: fila['destino'] as String,
      estado: EstadoViaje.desdeCodigo(fila['estado'] as String),
      placaVehiculo: vehiculo['placa'] as String,
      nombreConductor: usuarioConductor['nombre'] as String,
      nombreCliente: cliente['nombre'] as String,
      fechaSalidaProgramada: fila['fecha_salida_programada'] == null
          ? null
          : DateTime.parse(fila['fecha_salida_programada'] as String).toLocal(),
      fechaCreacion: DateTime.parse(fila['fecha_creacion'] as String).toLocal(),
      tiempoEstimadoMin: (fila['tiempo_estimado_min'] as num?)?.toDouble(),
      distanciaEstimada: (fila['distancia_estimada'] as num?)?.toDouble(),
      pesoCarga: (fila['peso_carga'] as num?)?.toDouble(),
      tipoVehiculo: vehiculo['tipo'] == null
          ? null
          : TipoVehiculo.desdeCodigo(vehiculo['tipo'] as String),
      origenCoordenada: _coordenada(fila['origen_lat'], fila['origen_lng']),
      destinoCoordenada: _coordenada(fila['destino_lat'], fila['destino_lng']),
      rutaPolilinea: fila['ruta_polilinea'] as String?,
    );
  }

  static Coordenada? _coordenada(Object? lat, Object? lng) {
    if (lat == null || lng == null) return null;
    return Coordenada((lat as num).toDouble(), (lng as num).toDouble());
  }
}
