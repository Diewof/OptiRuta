import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve la invocación de la Edge Function `rutas`. No traduce errores ni
/// conoce entidades: eso es responsabilidad del repositorio.
class RutaRemoteDataSource {
  RutaRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> estimar({
    required Map<String, double> origen,
    required Map<String, double> destino,
  }) => _invocar(<String, dynamic>{'origen': origen, 'destino': destino});

  Future<Map<String, dynamic>> buscar(String consulta) =>
      _invocar(<String, dynamic>{'consulta': consulta});

  Future<Map<String, dynamic>> lugarEn({
    required double lat,
    required double lng,
  }) => _invocar(<String, dynamic>{'lat': lat, 'lng': lng});

  Future<Map<String, dynamic>> _invocar(Map<String, dynamic> cuerpo) async {
    final FunctionResponse respuesta = await _client.functions.invoke(
      'rutas',
      body: cuerpo,
    );
    return respuesta.data as Map<String, dynamic>;
  }
}
