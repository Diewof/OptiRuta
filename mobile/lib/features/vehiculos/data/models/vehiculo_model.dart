import '../../domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/vehiculo.dart';

/// Mapea la fila de `public.vehiculo` (PostgREST) a la entidad de dominio y
/// construye los mapas de insercion/actualizacion.
abstract final class VehiculoModel {
  static Vehiculo aEntidad(Map<String, dynamic> fila) {
    return Vehiculo(
      id: fila['id'] as String,
      placa: fila['placa'] as String,
      tipo: TipoVehiculo.desdeCodigo(fila['tipo'] as String),
      capacidadCarga: (fila['capacidad_carga'] as num).toDouble(),
      rendimientoKmGalon: (fila['rendimiento_km_galon'] as num).toDouble(),
      activo: fila['activo'] as bool,
    );
  }

  static Map<String, dynamic> aFila({
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
  }) {
    return <String, dynamic>{
      'placa': placa,
      'tipo': tipo.codigo,
      'capacidad_carga': capacidadCarga,
      'rendimiento_km_galon': rendimientoKmGalon,
    };
  }
}
