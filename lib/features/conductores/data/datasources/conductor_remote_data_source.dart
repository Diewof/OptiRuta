import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.conductor` (con el `usuario` asociado
/// embebido) y a `public.usuario` por PostgREST. No traduce errores ni
/// conoce entidades de dominio: eso es responsabilidad del repositorio.
class ConductorRemoteDataSource {
  ConductorRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const String _seleccionConUsuario =
      '*, usuario:usuario_id(nombre, documento)';

  /// Pide `tamano + 1` filas para saber si hay una pagina siguiente sin un
  /// segundo viaje de red.
  Future<List<Map<String, dynamic>>> listar({
    required int pagina,
    required int tamano,
  }) {
    final int desde = pagina * tamano;
    return _client
        .from('conductor')
        .select(_seleccionConUsuario)
        .order('fecha_creacion', ascending: false)
        .range(desde, desde + tamano);
  }

  Future<Map<String, dynamic>?> obtenerPropio(String usuarioId) {
    return _client
        .from('conductor')
        .select(_seleccionConUsuario)
        .eq('usuario_id', usuarioId)
        .maybeSingle();
  }

  /// Usuarios con rol CONDUCTOR activos que aun no tienen fila en
  /// `conductor`. Se resuelve en dos pasos (sin RPC: es una consulta de
  /// lectura de apoyo a UI, no una operacion de dominio transaccional).
  Future<List<Map<String, dynamic>>> listarUsuariosDisponibles() async {
    final List<Map<String, dynamic>> conPerfil = await _client
        .from('conductor')
        .select('usuario_id');
    final List<String> idsConPerfil = conPerfil
        .map((Map<String, dynamic> fila) => fila['usuario_id'] as String)
        .toList();

    PostgrestFilterBuilder<List<Map<String, dynamic>>> consulta = _client
        .from('usuario')
        .select('id, nombre, documento')
        .eq('rol', 'CONDUCTOR')
        .eq('activo', true);

    if (idsConPerfil.isNotEmpty) {
      consulta = consulta.not('id', 'in', '(${idsConPerfil.join(',')})');
    }

    return consulta.order('nombre');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> fila) {
    return _client
        .from('conductor')
        .insert(fila)
        .select(_seleccionConUsuario)
        .single();
  }

  Future<Map<String, dynamic>> actualizar(
    String id,
    Map<String, dynamic> fila,
  ) {
    return _client
        .from('conductor')
        .update(fila)
        .eq('id', id)
        .select(_seleccionConUsuario)
        .single();
  }

  Future<void> inhabilitar(String id) {
    return _client
        .from('conductor')
        .update(<String, dynamic>{'activo': false})
        .eq('id', id);
  }
}
