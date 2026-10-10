import '../entities/coordenada.dart';
import '../entities/lugar.dart';
import '../repositories/ruta_repository.dart';

class LugarEnCoordenadaUseCase {
  const LugarEnCoordenadaUseCase(this._repositorio);

  final RutaRepository _repositorio;

  Future<Lugar> call(Coordenada coordenada) => _repositorio.lugarEn(coordenada);
}
