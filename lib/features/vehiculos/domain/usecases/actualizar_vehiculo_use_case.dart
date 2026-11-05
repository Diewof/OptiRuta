import '../entities/ficha_tecnica.dart';
import '../entities/tipo_vehiculo.dart';
import '../entities/vehiculo.dart';
import '../repositories/vehiculo_repository.dart';

class ActualizarVehiculoUseCase {
  const ActualizarVehiculoUseCase(this._repositorio);

  final VehiculoRepository _repositorio;

  Future<Vehiculo> call({
    required String id,
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
    FichaTecnica ficha = FichaTecnica.vacia,
  }) {
    return _repositorio.actualizar(
      id: id,
      placa: placa.trim().toUpperCase(),
      tipo: tipo,
      capacidadCarga: capacidadCarga,
      rendimientoKmGalon: rendimientoKmGalon,
      ficha: ficha,
    );
  }
}
