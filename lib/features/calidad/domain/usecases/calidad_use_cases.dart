import '../../../reportes/domain/entities/reporte.dart';
import '../entities/calidad.dart';
import '../repositories/calidad_repository.dart';

class ObtenerCalidadDeViajeUseCase {
  const ObtenerCalidadDeViajeUseCase(this._repositorio);

  final CalidadRepository _repositorio;

  Future<CalidadViaje?> call(String viajeId) =>
      _repositorio.calidadDeViaje(viajeId);
}

class ObtenerResumenCalidadUseCase {
  const ObtenerResumenCalidadUseCase(this._repositorio);

  final CalidadRepository _repositorio;

  Future<ResumenCalidad> call(FiltroReporte filtro) =>
      _repositorio.resumen(filtro);
}

class ObtenerCalidadDeConductorUseCase {
  const ObtenerCalidadDeConductorUseCase(this._repositorio);

  final CalidadRepository _repositorio;

  Future<ResumenCalidad> call(
    String conductorId,
    DateTime desde,
    DateTime hasta,
  ) => _repositorio.resumenDeConductor(conductorId, desde, hasta);
}

class ObtenerCalidadPorDimensionUseCase {
  const ObtenerCalidadPorDimensionUseCase(this._repositorio);

  final CalidadRepository _repositorio;

  Future<List<CalidadDimension>> call(
    FiltroReporte filtro,
    DimensionCalidad dimension,
  ) => _repositorio.porDimension(filtro, dimension);
}

class ListarAlertasRecurrentesUseCase {
  const ListarAlertasRecurrentesUseCase(this._repositorio);

  final CalidadRepository _repositorio;

  Future<List<AlertaRecurrente>> call(FiltroReporte filtro) =>
      _repositorio.recurrentes(filtro);
}
