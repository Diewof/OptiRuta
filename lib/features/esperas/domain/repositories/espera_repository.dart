import '../entities/espera_cliente.dart';

/// Contrato sobre la RPC `tiempos_espera` (solo administrador).
abstract interface class EsperaRepository {
  Future<List<EsperaCliente>> porCliente({
    required DateTime desde,
    required DateTime hasta,
  });
}
