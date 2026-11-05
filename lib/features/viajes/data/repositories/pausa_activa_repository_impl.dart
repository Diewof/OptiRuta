import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/repositories/pausa_activa_repository.dart';

/// Acceso a las RPC de pausa activa. Toma el cliente directo (misma forma que
/// `UbicacionViajeRepositoryImpl`: sin lógica propia que justifique otra capa).
class PausaActivaRepositoryImpl implements PausaActivaRepository {
  PausaActivaRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<void> probar({required String viajeId}) {
    return ejecutarCatalogo(
      () => _client.rpc(
        'viaje_probar_pausa_activa',
        params: <String, dynamic>{'p_viaje_id': viajeId},
      ),
    );
  }

  @override
  Future<bool> consumirPrueba({required String viajeId}) {
    return ejecutarCatalogo(() async {
      final dynamic hay = await _client.rpc(
        'viaje_consumir_pausa_prueba',
        params: <String, dynamic>{'p_viaje_id': viajeId},
      );
      return hay as bool;
    });
  }

  @override
  Future<bool> registrarIgnorada({
    required String viajeId,
    required int minutosConduccion,
    required int minutosIgnorada,
    required bool prueba,
  }) {
    return ejecutarCatalogo(() async {
      final dynamic creada = await _client.rpc(
        'viaje_registrar_pausa_ignorada',
        params: <String, dynamic>{
          'p_viaje_id': viajeId,
          'p_minutos_conduccion': minutosConduccion,
          'p_minutos_ignorada': minutosIgnorada,
          'p_prueba': prueba,
        },
      );
      return creada as bool;
    });
  }
}
