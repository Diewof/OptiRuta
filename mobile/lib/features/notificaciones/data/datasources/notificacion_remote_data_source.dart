import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.notificacion` por PostgREST. No traduce
/// errores ni conoce entidades de dominio: eso es responsabilidad del
/// repositorio.
class NotificacionRemoteDataSource {
  NotificacionRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Pide `tamano + 1` filas para saber si hay una pagina siguiente sin un
  /// segundo viaje de red.
  ///
  /// [desde] (inclusive) y [hasta] (exclusive) acotan por fecha de creación;
  /// con [soloNoLeidas] solo trae las pendientes.
  Future<List<Map<String, dynamic>>> listar({
    required int pagina,
    required int tamano,
    DateTime? desde,
    DateTime? hasta,
    bool soloNoLeidas = false,
  }) {
    final int inicio = pagina * tamano;
    PostgrestFilterBuilder<List<Map<String, dynamic>>> consulta = _client
        .from('notificacion')
        .select();
    if (soloNoLeidas) consulta = consulta.eq('leida', false);
    if (desde != null) {
      consulta = consulta.gte(
        'fecha_creacion',
        desde.toUtc().toIso8601String(),
      );
    }
    if (hasta != null) {
      consulta = consulta.lt('fecha_creacion', hasta.toUtc().toIso8601String());
    }
    return consulta
        .order('fecha_creacion', ascending: false)
        .range(inicio, inicio + tamano);
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
