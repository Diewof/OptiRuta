import '../entities/ajuste_viaje.dart';

/// Contrato sobre `ajuste_viaje`: lectura (RLS: administrador y conductor
/// propietario) y registro por la RPC `viaje_registrar_ajuste` (solo
/// administrador, motivo obligatorio). No hay UPDATE ni DELETE.
abstract interface class AjusteViajeRepository {
  /// Más reciente primero.
  Future<List<AjusteViaje>> listarPorViaje(String viajeId);

  Future<AjusteViaje> registrar({
    required String viajeId,
    required String motivo,
    String? campoModificado,
    String? valorAnterior,
    String? valorNuevo,
  });
}
