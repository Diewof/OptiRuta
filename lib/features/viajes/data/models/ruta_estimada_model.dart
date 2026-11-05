import '../../domain/entities/coordenada.dart';
import '../../domain/entities/lugar.dart';
import '../../domain/entities/ruta_estimada.dart';

abstract final class RutaEstimadaModel {
  static RutaEstimada aEntidad(Map<String, dynamic> fila) {
    return RutaEstimada(
      distanciaKm: (fila['distanciaKm'] as num).toDouble(),
      duracionMin: (fila['duracionMin'] as num).toDouble(),
      polilinea: (fila['polilinea'] as String?) ?? '',
    );
  }
}

/// Mapea un lugar de la Edge Function `rutas` (`{ nombre, lat, lng }`).
abstract final class LugarModel {
  static Lugar aEntidad(Map<String, dynamic> fila) {
    return Lugar(
      nombre: fila['nombre'] as String,
      coordenada: Coordenada(
        (fila['lat'] as num).toDouble(),
        (fila['lng'] as num).toDouble(),
      ),
    );
  }
}
