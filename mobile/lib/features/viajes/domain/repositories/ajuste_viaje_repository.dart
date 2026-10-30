import '../entities/ajuste_viaje.dart';

/// Contrato sobre `ajuste_viaje`: lectura (RLS: administrador y conductor
/// propietario) y registro por la RPC `viaje_registrar_ajuste_v2` (solo
/// administrador, viaje cerrado, motivo obligatorio). No hay UPDATE ni DELETE.
abstract interface class AjusteViajeRepository {
  /// Más reciente primero.
  Future<List<AjusteViaje>> listarPorViaje(String viajeId);

  Future<AjusteViaje> registrar({
    required String viajeId,
    required String motivo,
    required String concepto,
    required double valorNuevo,
  });
}
