import '../entities/informe.dart';
import '../entities/reporte.dart';

/// Contrato sobre la RPC `reporte_viajes` (solo ADMINISTRADOR).
abstract interface class ReporteRepository {
  Future<List<FilaReporte>> viajes(FiltroReporte filtro);
}

/// Genera y comparte un informe en un archivo (RF-28). La implementación
/// vive en `data` para que el dominio no dependa del paquete de PDF.
abstract interface class ExportadorReporte {
  Future<void> exportarPdf({
    required Informe informe,
    required String descripcionFiltros,
    required String nombreArchivo,
  });
}
