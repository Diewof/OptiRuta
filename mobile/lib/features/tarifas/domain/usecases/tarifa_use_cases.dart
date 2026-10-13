import '../entities/tarifa_combustible.dart';
import '../repositories/tarifa_combustible_repository.dart';

class ListarTarifasUseCase {
  const ListarTarifasUseCase(this._repositorio);

  final TarifaCombustibleRepository _repositorio;

  Future<List<TarifaCombustible>> call() => _repositorio.listar();
}

/// Registra una tarifa nueva. Valida lo mínimo por UX; el precio positivo y
/// la unicidad ciudad + fecha los garantiza Postgres.
class RegistrarTarifaUseCase {
  const RegistrarTarifaUseCase(this._repositorio);

  final TarifaCombustibleRepository _repositorio;

  Future<TarifaCombustible> call({
    required String ciudad,
    required double precioGalon,
    required DateTime fechaVigenciaDesde,
  }) {
    final String limpia = ciudad.trim();
    if (limpia.isEmpty) {
      throw ArgumentError.value(ciudad, 'ciudad', 'La ciudad es obligatoria.');
    }
    if (precioGalon <= 0) {
      throw ArgumentError.value(precioGalon, 'precioGalon', 'Debe ser > 0.');
    }
    return _repositorio.registrar(
      ciudad: limpia,
      precioGalon: precioGalon,
      fechaVigenciaDesde: fechaVigenciaDesde,
    );
  }
}

class ActualizarPrecioTarifaUseCase {
  const ActualizarPrecioTarifaUseCase(this._repositorio);

  final TarifaCombustibleRepository _repositorio;

  Future<TarifaCombustible> call({
    required String id,
    required double precioGalon,
  }) {
    if (precioGalon <= 0) {
      throw ArgumentError.value(precioGalon, 'precioGalon', 'Debe ser > 0.');
    }
    return _repositorio.actualizarPrecio(id: id, precioGalon: precioGalon);
  }
}
