import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.notificacion` por PostgREST. No traduce
/// errores ni conoce entidades de dominio: eso es responsabilidad del
/// repositorio.
class NotificacionRemoteDataSource {
  NotificacionRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Pide `tamano + 1` filas para saber si hay una pagina siguiente sin un
  /// segundo viaje de red.
  Future<List<Map<String, dynamic>>> listar({
    required int pagina,
    required int tamano,
  }) {
    final int desde = pagina * tamano;
    return _client
        .from('notificacion')
        .select()
        .order('fecha_creacion', ascending: false)
        .range(desde, desde + tamano);
  }

  Future<void> marcarLeida(String id) {
    return _client
        .from('notificacion')
        .update(<String, dynamic>{'leida': true})
        .eq('id', id);
  }

  Future<void> marcarTodasLeidas() {
    return _client
        .from('notificacion')
        .update(<String, dynamic>{'leida': true})
        .eq('leida', false);
  }
}
