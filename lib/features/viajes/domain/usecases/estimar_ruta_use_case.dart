import '../entities/coordenada.dart';
import '../entities/ruta_estimada.dart';
import '../repositories/ruta_repository.dart';

class EstimarRutaUseCase {
  const EstimarRutaUseCase(this._repositorio);

  final RutaRepository _repositorio;

  Future<RutaEstimada> call({
    required Coordenada origen,
    required Coordenada destino,
  }) => _repositorio.estimar(origen: origen, destino: destino);
}
