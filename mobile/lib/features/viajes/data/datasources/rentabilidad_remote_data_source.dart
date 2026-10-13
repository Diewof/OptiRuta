import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve las RPC de rentabilidad (`rentabilidad_marginal`,
/// `rentabilidad_consolidada`). Ambas devuelven exactamente una fila
/// (agregados calculados con subconsultas, no `group by`).
class RentabilidadRemoteDataSource {
  RentabilidadRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> marginal(String viajeId) {
    return _client
        .rpc(
          'rentabilidad_marginal',
          params: <String, dynamic>{'p_viaje_id': viajeId},
        )
        .single();
  }

  Future<Map<String, dynamic>> consolidada({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) {
    String soloFecha(DateTime f) => f.toIso8601String().split('T').first;
    return _client
        .rpc(
          'rentabilidad_consolidada_v3',
          params: <String, dynamic>{
            'p_desde': soloFecha(desde),
            'p_hasta': soloFecha(hasta),
            'p_cliente_id': clienteId,
            'p_conductor_id': conductorId,
            'p_vehiculo_id': vehiculoId,
            'p_ruta': ruta,
          },
        )
        .single();
  }
}
