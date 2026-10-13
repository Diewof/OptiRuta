import '../entities/rentabilidad_consolidada.dart';
import '../entities/rentabilidad_marginal.dart';

/// Contrato sobre las RPC de rentabilidad. Dos funciones separadas
/// (marginal/consolidada), no un motor genérico (patrón Strategy acotado,
/// ver CLAUDE.md "Patrones").
abstract interface class RentabilidadRepository {
  Future<RentabilidadMarginal> marginal(String viajeId);

  /// Los filtros son opcionales; un nulo no filtra. Con cliente o ruta el
  /// mantenimiento y el sueldo fijo no son atribuibles y valen 0 (ver
  /// `rentabilidad_consolidada_v2`).
  Future<RentabilidadConsolidada> consolidada({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  });
}
