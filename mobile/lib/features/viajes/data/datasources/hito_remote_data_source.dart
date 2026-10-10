import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.hito_viaje`: lectura por viaje y registro
/// (INSERT) de un hito nuevo por el conductor.
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

  Future<Map<String, dynamic>> registrar({
    required String viajeId,
    required String tipo,
    required DateTime fechaHora,
  }) async {
    final List<Map<String, dynamic>> filas = await _client
        .from('hito_viaje')
        .insert(<String, dynamic>{
          'viaje_id': viajeId,
          'tipo': tipo,
          'fecha_hora': fechaHora.toIso8601String(),
        })
        .select();
    return filas.first;
  }
}
