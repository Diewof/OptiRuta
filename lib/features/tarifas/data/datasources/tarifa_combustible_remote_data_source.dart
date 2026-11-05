import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.tarifa_combustible` por PostgREST. No traduce
/// errores ni conoce entidades: eso es del repositorio.
class TarifaCombustibleRemoteDataSource {
  TarifaCombustibleRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listar() {
    return _client
        .from('tarifa_combustible')
        .select()
        .order('fecha_vigencia_desde', ascending: false)
        .order('ciudad');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> fila) {
    return _client.from('tarifa_combustible').insert(fila).select().single();
  }

  Future<Map<String, dynamic>> actualizarPrecio(String id, double precioGalon) {
    return _client
        .from('tarifa_combustible')
        .update(<String, dynamic>{
          'precio_galon': precioGalon,
          'fuente': 'MANUAL',
        })
        .eq('id', id)
        .select()
        .single();
  }
}
