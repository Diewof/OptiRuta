import '../entities/viaje_resumen.dart';
import '../repositories/viaje_repository.dart';

class ObtenerViajeResumenUseCase {
  const ObtenerViajeResumenUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<ViajeResumen> call(String viajeId) =>
      _repositorio.obtenerResumen(viajeId);
}
