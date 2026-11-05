import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve las RPC de combustible.
class CombustibleRemoteDataSource {
  CombustibleRemoteDataSource(this._client);

  final SupabaseClient _client;

  static String _soloFecha(DateTime f) => f.toIso8601String().split('T').first;

  Future<void> registrarTanqueo({
    required String viajeId,
    required double galones,
    required double valor,
  }) async {
    await _client.rpc(
      'viaje_registrar_tanqueo',
      params: <String, dynamic>{
        'p_viaje_id': viajeId,
        'p_galones': galones,
        'p_valor': valor,
      },
    );
  }

  Future<List<Map<String, dynamic>>> rendimiento({
    required DateTime desde,
    required DateTime hasta,
    required String dimension,
  }) async {
    final List<dynamic> filas = await _client.rpc(
      'combustible_rendimiento',
      params: <String, dynamic>{
        'p_desde': _soloFecha(desde),
        'p_hasta': _soloFecha(hasta),
        'p_dimension': dimension,
      },
    );
    return filas.cast<Map<String, dynamic>>();
  }
}
