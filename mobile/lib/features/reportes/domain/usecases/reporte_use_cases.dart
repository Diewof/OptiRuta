import '../entities/informe.dart';
import '../repositories/reporte_repository.dart';

class ExportarReportePdfUseCase {
  const ExportarReportePdfUseCase(this._exportador);

  final ExportadorReporte _exportador;

  Future<void> call({
    required Informe informe,
    required String descripcionFiltros,
    required String nombreArchivo,
  }) {
    if (informe.filas.isEmpty) {
      throw StateError('No hay datos para exportar.');
    }
    return _exportador.exportarPdf(
      informe: informe,
      descripcionFiltros: descripcionFiltros,
      nombreArchivo: nombreArchivo,
    );
  }
}
