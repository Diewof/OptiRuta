import '../../domain/entities/ficha_tecnica.dart';
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
      ficha: FichaTecnica(
        marca: fila['marca'] as String?,
        linea: fila['linea'] as String?,
        modeloAnio: (fila['modelo_anio'] as num?)?.toInt(),
        vin: fila['vin'] as String?,
        numeroMotor: fila['numero_motor'] as String?,
        numeroEjes: (fila['numero_ejes'] as num?)?.toInt(),
        cantidadLlantas: (fila['cantidad_llantas'] as num?)?.toInt(),
        pbvKg: (fila['pbv_kg'] as num?)?.toDouble(),
        odometroInicialKm:
            (fila['odometro_inicial_km'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  static Map<String, dynamic> aFila({
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
    FichaTecnica ficha = FichaTecnica.vacia,
  }) {
    return <String, dynamic>{
      'placa': placa,
      'tipo': tipo.codigo,
      'capacidad_carga': capacidadCarga,
      'rendimiento_km_galon': rendimientoKmGalon,
      'marca': _texto(ficha.marca),
      'linea': _texto(ficha.linea),
      'modelo_anio': ficha.modeloAnio,
      'vin': _texto(ficha.vin)?.toUpperCase(),
      'numero_motor': _texto(ficha.numeroMotor),
      'numero_ejes': ficha.numeroEjes,
      'cantidad_llantas': ficha.cantidadLlantas,
      'pbv_kg': ficha.pbvKg,
      'odometro_inicial_km': ficha.odometroInicialKm,
    };
  }

  static String? _texto(String? valor) {
    final String? limpio = valor?.trim();
    return limpio == null || limpio.isEmpty ? null : limpio;
  }
}
