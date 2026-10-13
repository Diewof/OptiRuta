import '../../../dashboard/domain/entities/metricas.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../entities/satisfaccion.dart';

/// Contrato sobre las RPC `satisfaccion_*` (solo ADMINISTRADOR; lo exige la
/// propia RPC). Los filtros son los mismos del Resumen de costos.
abstract interface class SatisfaccionRepository {
  Future<ResumenSatisfaccion> resumen(FiltroReporte filtro);

  Future<List<SatisfaccionDimension>> porDimension(
    FiltroReporte filtro,
    DimensionMetrica dimension,
  );

  Future<List<ComentarioSatisfaccion>> comentarios(
    FiltroReporte filtro, {
    int limite = 20,
  });

  /// La encuesta del viaje, o `null` si todavía no se generó (el viaje no ha
  /// finalizado).
  Future<EncuestaViaje?> encuestaDeViaje(String viajeId);
}
