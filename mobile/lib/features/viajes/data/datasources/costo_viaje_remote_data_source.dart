import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.costo_viaje`: lectura por viaje y la única
/// escritura permitida desde la app (`valor_real`); RLS/trigger deciden qué
/// filas y columnas puede tocar quien llama.
class CostoViajeRemoteDataSource {
  CostoViajeRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listarPorViaje(String viajeId) {
    return _client
        .from('costo_viaje')
        .select()
        .eq('viaje_id', viajeId)
        .order('categoria');
  }

  Future<Map<String, dynamic>> actualizarValorReal({
    required String costoId,
    required double valorReal,
  }) async {
    final List<Map<String, dynamic>> filas = await _client
        .from('costo_viaje')
        .update(<String, dynamic>{'valor_real': valorReal})
        .eq('id', costoId)
        .select();
    return filas.first;
  }
}
