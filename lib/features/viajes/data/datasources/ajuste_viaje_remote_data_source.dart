import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso a `public.ajuste_viaje` (lectura) y a la RPC
/// `viaje_registrar_ajuste_v2` (única escritura: la tabla no tiene grant de
/// UPDATE/DELETE, el motivo es obligatorio y el servidor calcula la
/// diferencia contra el valor vigente).
class AjusteViajeRemoteDataSource {
  AjusteViajeRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listarPorViaje(String viajeId) {
    return _client
        .from('ajuste_viaje')
        .select()
        .eq('viaje_id', viajeId)
        .order('fecha', ascending: false);
  }

  Future<Map<String, dynamic>> registrar({
    required String viajeId,
    required String motivo,
    required String concepto,
    required double valorNuevo,
  }) async {
    final dynamic fila = await _client.rpc(
      'viaje_registrar_ajuste_v2',
      params: <String, dynamic>{
        'p_viaje_id': viajeId,
        'p_motivo': motivo,
        'p_concepto': concepto,
        'p_valor_nuevo': valorNuevo,
      },
    );
    return fila as Map<String, dynamic>;
  }
}
