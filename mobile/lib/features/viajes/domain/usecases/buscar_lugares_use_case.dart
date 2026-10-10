import '../entities/lugar.dart';
import '../repositories/ruta_repository.dart';

class BuscarLugaresUseCase {
  const BuscarLugaresUseCase(this._repositorio);

  /// Con menos letras el autocompletado solo devuelve ruido y gasta la cuota
  /// del servicio público.
  static const int minimoCaracteres = 3;

  final RutaRepository _repositorio;

  Future<List<Lugar>> call(String consulta) {
    final String limpia = consulta.trim();
    if (limpia.length < minimoCaracteres) {
      return Future<List<Lugar>>.value(const <Lugar>[]);
    }
    return _repositorio.buscarLugares(limpia);
  }
}
