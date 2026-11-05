import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.hito_viaje`: lectura por viaje y registro de
/// un hito nuevo por el conductor (RPC).
class HitoRemoteDataSource {
  HitoRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listarPorViaje(String viajeId) {
    return _client
        .from('hito_viaje')
        .select()
        .eq('viaje_id', viajeId)
        .order('fecha_hora');
  }

  /// Registra un hito vía la RPC `viaje_registrar_hito`: el servidor valida
  /// el orden y, con LLEGADA_DESTINO, deja el viaje FINALIZADO.
  Future<Map<String, dynamic>> registrar({
    required String viajeId,
    required String tipo,
    required DateTime fechaHora,
  }) async {
    final dynamic fila = await _client.rpc(
      'viaje_registrar_hito',
      params: <String, dynamic>{
        'p_viaje_id': viajeId,
        'p_tipo': tipo,
        'p_fecha_hora': fechaHora.toUtc().toIso8601String(),
      },
    );
    return fila as Map<String, dynamic>;
  }

  /// RPC `viaje_descargue_pendiente`: cero o una fila.
  Future<List<Map<String, dynamic>>> descarguePendiente() async {
    final List<dynamic> filas = await _client.rpc('viaje_descargue_pendiente');
    return filas.cast<Map<String, dynamic>>();
  }
}
