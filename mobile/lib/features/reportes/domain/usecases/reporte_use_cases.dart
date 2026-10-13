import '../entities/reporte.dart';
import '../repositories/reporte_repository.dart';

class ObtenerReporteViajesUseCase {
  const ObtenerReporteViajesUseCase(this._repositorio);

  final ReporteRepository _repositorio;

  Future<List<FilaReporte>> call(FiltroReporte filtro) {
    if (filtro.desde.isAfter(filtro.hasta)) {
      throw ArgumentError.value(
        filtro.desde,
        'desde',
        'La fecha inicial no puede ser posterior a la final.',
      );
    }
    return _repositorio.viajes(filtro);
  }
}

class ExportarReportePdfUseCase {
  const ExportarReportePdfUseCase(this._exportador);

  final ExportadorReporte _exportador;

  Future<void> call({
    required FiltroReporte filtro,
    required String descripcionFiltros,
    required List<FilaReporte> filas,
  }) {
    if (filas.isEmpty) {
      throw StateError('No hay viajes para exportar.');
    }
    return _exportador.exportarPdf(
      filtro: filtro,
      descripcionFiltros: descripcionFiltros,
      filas: filas,
    );
  }
}
