import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve las RPC de métricas. `metricas_periodo` devuelve una sola fila;
/// `metricas_por_dimension`, una por ruta/cliente/conductor.
class MetricasRemoteDataSource {
  MetricasRemoteDataSource(this._client);

  final SupabaseClient _client;

  static String _soloFecha(DateTime f) => f.toIso8601String().split('T').first;

  Future<Map<String, dynamic>> periodo({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) {
    return _client
        .rpc(
          'metricas_periodo_v2',
          params: <String, dynamic>{
            'p_desde': _soloFecha(desde),
            'p_hasta': _soloFecha(hasta),
            'p_cliente_id': clienteId,
            'p_conductor_id': conductorId,
            'p_vehiculo_id': vehiculoId,
            'p_ruta': ruta,
          },
        )
        .single();
  }

  Future<List<Map<String, dynamic>>> porDimension({
    required DateTime desde,
    required DateTime hasta,
    required String dimension,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) async {
    final List<dynamic> filas = await _client.rpc(
      'metricas_por_dimension_v2',
      params: <String, dynamic>{
        'p_desde': _soloFecha(desde),
        'p_hasta': _soloFecha(hasta),
        'p_dimension': dimension,
        'p_cliente_id': clienteId,
        'p_conductor_id': conductorId,
        'p_vehiculo_id': vehiculoId,
        'p_ruta': ruta,
      },
    );
    return filas.cast<Map<String, dynamic>>();
  }
}
