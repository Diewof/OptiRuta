import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/repositories/ubicacion_viaje_repository.dart';

/// Acceso a `conductor_consentimiento_ubicacion`, `viaje_registrar_ubicacion`
/// y `ubicacion_viaje`. Toma el cliente directo (misma forma que las demás
/// fuentes de datos, sin lógica propia que justifique otra capa).
class UbicacionViajeRepositoryImpl implements UbicacionViajeRepository {
  UbicacionViajeRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> consentimientoVigente() {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic>? fila = await _client
          .from('conductor')
          .select('consentimiento_ubicacion_fecha')
          .maybeSingle();
      return fila?['consentimiento_ubicacion_fecha'] != null;
    });
  }

  @override
  Future<bool> responderConsentimiento({required bool acepta}) {
    return ejecutarCatalogo(() async {
      final dynamic fecha = await _client.rpc(
        'conductor_consentimiento_ubicacion',
        params: <String, dynamic>{'p_acepta': acepta},
      );
      return fecha != null;
    });
  }

  @override
  Future<bool> registrarPunto({
    required String viajeId,
    required Coordenada posicion,
  }) {
    return ejecutarCatalogo(() async {
      final dynamic guardado = await _client.rpc(
        'viaje_registrar_ubicacion',
        params: <String, dynamic>{
          'p_viaje_id': viajeId,
          'p_lat': posicion.lat,
          'p_lng': posicion.lng,
        },
      );
      return guardado as bool;
    });
  }

  @override
  Future<List<PuntoUbicacion>> listarPuntos(String viajeId) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _client
          .from('ubicacion_viaje')
          .select('lat, lng, fecha_hora')
          .eq('viaje_id', viajeId)
          .order('fecha_hora', ascending: false)
          .limit(200);
      return filas
          .map(
            (Map<String, dynamic> f) => PuntoUbicacion(
              posicion: Coordenada(
                (f['lat'] as num).toDouble(),
                (f['lng'] as num).toDouble(),
              ),
              fechaHora: DateTime.parse(f['fecha_hora'] as String).toLocal(),
            ),
          )
          .toList();
    });
  }
}
