import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve el acceso a `public.viaje` y sus RPC de dominio
/// (`viaje_crear`, `viaje_cambiar_estado`, `viaje_cerrar`). No traduce
/// errores ni conoce entidades: eso es responsabilidad del repositorio.
class ViajeRemoteDataSource {
  ViajeRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Embed de PostgREST reutilizado por todos los listados: trae la placa
  /// del vehículo, el nombre del conductor (join anidado a través de
  /// `usuario`) y el nombre del cliente en la misma consulta.
  static const String _embedResumen =
      '*, vehiculo:vehiculo_id(placa, tipo), '
      'conductor:conductor_id(usuario:usuario_id(nombre)), '
      'cliente:cliente_id(nombre)';

  Future<Map<String, dynamic>> crear(Map<String, dynamic> parametros) async {
    final dynamic fila = await _client.rpc(
      'viaje_crear_v2',
      params: parametros,
    );
    return fila as Map<String, dynamic>;
  }

  Future<bool> registrarAlerta(Map<String, dynamic> parametros) async {
    final dynamic creada = await _client.rpc(
      'viaje_registrar_alerta',
      params: parametros,
    );
    return creada as bool;
  }

  Future<Map<String, dynamic>> cambiarEstado({
    required String viajeId,
    required String nuevoEstado,
  }) async {
    final dynamic fila = await _client.rpc(
      'viaje_cambiar_estado',
      params: <String, dynamic>{
        'p_viaje_id': viajeId,
        'p_nuevo_estado': nuevoEstado,
      },
    );
    return fila as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> iniciar(Map<String, dynamic> parametros) async {
    final dynamic fila = await _client.rpc('viaje_iniciar', params: parametros);
    return fila as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cerrar(String viajeId) async {
    final dynamic fila = await _client.rpc(
      'viaje_cerrar',
      params: <String, dynamic>{'p_viaje_id': viajeId},
    );
    return fila as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> obtenerResumen(String viajeId) {
    return _client
        .from('viaje')
        .select(_embedResumen)
        .eq('id', viajeId)
        .single();
  }

  Future<double> estimarAcpm({
    required String vehiculoId,
    required double distanciaKm,
    required String ciudad,
  }) async {
    final dynamic valor = await _client.rpc(
      'costo_acpm_estimado',
      params: <String, dynamic>{
        'p_vehiculo_id': vehiculoId,
        'p_distancia_km': distanciaKm,
        'p_ciudad': ciudad,
      },
    );
    return (valor as num).toDouble();
  }

  /// Viajes cuya `fecha_salida_programada` cae en `[desde, hasta)`.
  Future<List<Map<String, dynamic>>> listarPorRango({
    required DateTime desde,
    required DateTime hasta,
  }) {
    return _client
        .from('viaje')
        .select(_embedResumen)
        .gte('fecha_salida_programada', desde.toIso8601String())
        .lt('fecha_salida_programada', hasta.toIso8601String())
        .order('fecha_salida_programada');
  }

  Future<List<Map<String, dynamic>>> listarActivos() {
    return _client
        .from('viaje')
        .select(_embedResumen)
        .inFilter('estado', <String>['ASIGNADO', 'EN_CURSO'])
        .order('fecha_salida_programada');
  }

  /// Pide `tamano + 1` filas para saber si hay una página siguiente sin un
  /// segundo viaje de red.
  Future<List<Map<String, dynamic>>> listarHistorial({
    required int pagina,
    required int tamano,
    String? filtroEstado,
  }) {
    final int desde = pagina * tamano;
    var query = _client.from('viaje').select(_embedResumen);
    if (filtroEstado != null) {
      query = query.eq('estado', filtroEstado);
    }
    return query
        .order('fecha_creacion', ascending: false)
        .range(desde, desde + tamano);
  }
}
