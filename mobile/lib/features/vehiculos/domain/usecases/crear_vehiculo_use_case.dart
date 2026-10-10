import '../entities/tipo_vehiculo.dart';
import '../entities/vehiculo.dart';
import '../repositories/vehiculo_repository.dart';

/// Crea un vehiculo. Normaliza la placa (recorta y pone en mayusculas); la
/// unicidad y el resto de validaciones las garantiza la BD (constraint +
/// RLS), esto es solo higiene del dato antes de enviarlo.
class CrearVehiculoUseCase {
  const CrearVehiculoUseCase(this._repositorio);

  final VehiculoRepository _repositorio;

  Future<Vehiculo> call({
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
  }) {
    return _repositorio.crear(
      placa: placa.trim().toUpperCase(),
      tipo: tipo,
      capacidadCarga: capacidadCarga,
      rendimientoKmGalon: rendimientoKmGalon,
    );
  }
}
