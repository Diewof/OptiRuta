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

  /// Inserta un costo adicional libre (categoría OTRO con descripción).
  Future<Map<String, dynamic>> agregarOtro({
    required String viajeId,
    required String descripcion,
    required double valorEstimado,
    double? valorReal,
  }) async {
    final List<Map<String, dynamic>> filas = await _client
        .from('costo_viaje')
        .insert(<String, dynamic>{
          'viaje_id': viajeId,
          'categoria': 'OTRO',
          'descripcion': descripcion,
          'valor_estimado': valorEstimado,
          'valor_real': valorReal,
          'fuente': 'MANUAL',
        })
        .select();
    return filas.first;
  }

  Future<Map<String, dynamic>> actualizarEstimado({
    required String costoId,
    required double valorEstimado,
  }) async {
    final List<Map<String, dynamic>> filas = await _client
        .from('costo_viaje')
        .update(<String, dynamic>{'valor_estimado': valorEstimado})
        .eq('id', costoId)
        .select();
    return filas.first;
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
