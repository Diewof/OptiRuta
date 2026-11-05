import '../repositories/vehiculo_repository.dart';

class ListarVehiculosUseCase {
  const ListarVehiculosUseCase(this._repositorio);

  final VehiculoRepository _repositorio;

  Future<PaginaVehiculos> call({required int pagina, int tamano = 20}) {
    return _repositorio.listar(pagina: pagina, tamano: tamano);
  }
}
