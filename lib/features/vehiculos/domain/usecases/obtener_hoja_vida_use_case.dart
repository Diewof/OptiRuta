import '../entities/hoja_vida.dart';
import '../repositories/hoja_vida_repository.dart';

class ObtenerHojaVidaUseCase {
  const ObtenerHojaVidaUseCase(this._repositorio);

  final HojaVidaRepository _repositorio;

  Future<HojaVida> call(String vehiculoId) => _repositorio.obtener(vehiculoId);
}
