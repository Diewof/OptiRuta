import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve la RPC `tiempos_espera`.
class EsperaRemoteDataSource {
  EsperaRemoteDataSource(this._client);

  final SupabaseClient _client;

  static String _soloFecha(DateTime f) => f.toIso8601String().split('T').first;

  Future<List<Map<String, dynamic>>> porCliente({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final List<dynamic> filas = await _client.rpc(
      'tiempos_espera',
      params: <String, dynamic>{
        'p_desde': _soloFecha(desde),
        'p_hasta': _soloFecha(hasta),
      },
    );
    return filas.cast<Map<String, dynamic>>();
  }
}
