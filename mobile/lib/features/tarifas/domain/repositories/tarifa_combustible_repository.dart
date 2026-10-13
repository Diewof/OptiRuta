import '../entities/tarifa_combustible.dart';

/// Contrato de acceso a `public.tarifa_combustible`. Lectura para cualquier
/// sesión; escritura solo ADMINISTRADOR (RLS). No hay borrado: una tarifa
/// nueva con fecha posterior reemplaza a la anterior en el cálculo.
abstract interface class TarifaCombustibleRepository {
  /// Todas las tarifas, la más reciente primero.
  Future<List<TarifaCombustible>> listar();

  Future<TarifaCombustible> registrar({
    required String ciudad,
    required double precioGalon,
    required DateTime fechaVigenciaDesde,
  });

  /// Corrige el precio de una tarifa ya registrada.
  Future<TarifaCombustible> actualizarPrecio({
    required String id,
    required double precioGalon,
  });
}
