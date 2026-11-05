import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.cliente` por PostgREST. No traduce errores
/// ni conoce entidades de dominio: eso es responsabilidad del repositorio.
class ClienteRemoteDataSource {
  ClienteRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Pide `tamano + 1` filas para saber si hay una pagina siguiente sin un
  /// segundo viaje de red.
  Future<List<Map<String, dynamic>>> listar({
    required int pagina,
    required int tamano,
  }) {
    final int desde = pagina * tamano;
    return _client
        .from('cliente')
        .select()
        .order('nombre')
        .range(desde, desde + tamano);
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> fila) {
    return _client.from('cliente').insert(fila).select().single();
  }

  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> fila,
  ) {
    return _client.from('cliente').update(fila).eq('id', id).select().single();
  }

  Future<void> inhabilitar(String id) {
    return _client
        .from('cliente')
        .update(<String, dynamic>{'activo': false})
        .eq('id', id);
  }
}
