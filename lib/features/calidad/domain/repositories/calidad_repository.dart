import '../../../reportes/domain/entities/reporte.dart';
import '../entities/calidad.dart';

/// Contrato sobre las RPC `viaje_calidad` y `calidad_*` (solo ADMINISTRADOR;
/// lo exige la propia RPC). Los filtros son los mismos del Resumen de costos.
abstract interface class CalidadRepository {
  /// La calificación del viaje, o `null` si aún no está finalizado.
  Future<CalidadViaje?> calidadDeViaje(String viajeId);

  Future<ResumenCalidad> resumen(FiltroReporte filtro);

  /// Indicador del perfil del conductor. El administrador consulta el de
  /// cualquiera; el conductor solo el suyo (lo exige la RPC).
  Future<ResumenCalidad> resumenDeConductor(
    String conductorId,
    DateTime desde,
    DateTime hasta,
  );

  Future<List<CalidadDimension>> porDimension(
    FiltroReporte filtro,
    DimensionCalidad dimension,
  );

  /// Alertas recurrentes del período (3 o más viajes en rojo).
  Future<List<AlertaRecurrente>> recurrentes(FiltroReporte filtro);
}
