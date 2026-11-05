import '../entities/rendimiento_combustible.dart';

/// Contrato sobre las RPC `viaje_registrar_tanqueo` (conductor) y
/// `combustible_rendimiento` (administrador). Las reglas las aplica el
/// servidor.
abstract interface class CombustibleRepository {
  /// Registra un tanqueo del viaje en curso del conductor autenticado.
  Future<void> registrarTanqueo({
    required String viajeId,
    required double galones,
    required double valor,
  });

  Future<List<RendimientoCombustible>> rendimiento({
    required DateTime desde,
    required DateTime hasta,
    required DimensionCombustible dimension,
  });
}
