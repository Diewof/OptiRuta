import '../entities/coordenada.dart';
import '../entities/lugar.dart';
import '../entities/ruta_estimada.dart';

/// Contrato sobre la Edge Function `rutas` (proveedor externo de mapas): la
/// única integración externa que necesita Agendar viaje para buscar lugares y
/// estimar distancia, tiempo y trazado. No vive en Postgres (CLAUDE.md
/// "Edge Functions").
abstract interface class RutaRepository {
  Future<RutaEstimada> estimar({
    required Coordenada origen,
    required Coordenada destino,
  });

  /// Autocompletado: lugares de Colombia que coinciden con lo escrito.
  Future<List<Lugar>> buscarLugares(String consulta);

  /// Nombre del lugar donde el administrador dejó el pin en el mapa.
  Future<Lugar> lugarEn(Coordenada coordenada);
}
