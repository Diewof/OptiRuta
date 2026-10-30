import '../entities/espera_cliente.dart';
import '../repositories/espera_repository.dart';

class ObtenerEsperasPorClienteUseCase {
  const ObtenerEsperasPorClienteUseCase(this._repositorio);

  final EsperaRepository _repositorio;

  Future<List<EsperaCliente>> call({
    required DateTime desde,
    required DateTime hasta,
  }) => _repositorio.porCliente(desde: desde, hasta: hasta);
}
