import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/catalogo_failure.dart';
import '../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../domain/entities/checklist.dart';
import '../domain/repositories/checklist_repository.dart';

/// Checklist sobre PostgREST: catálogo y lectura por tabla; escritura solo por
/// las RPC `checklist_registrar` y `checklist_autorizar_salida`.
class ChecklistRepositoryImpl implements ChecklistRepository {
  ChecklistRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const String _columnas =
      'id, viaje_id, fecha_hora, resultado, observaciones, '
      'autorizacion:checklist_autorizacion(motivo), '
      'respuestas:checklist_respuesta(estado, critico, observacion, '
      'item:item_id(nombre))';

  static ChecklistViaje aEntidad(Map<String, dynamic> f) {
    // PostgREST devuelve un objeto (relación uno a uno) o una lista según la
    // cardinalidad que infiera; se aceptan ambas.
    final Object? aut = f['autorizacion'];
    final Map<String, dynamic>? autorizacion = switch (aut) {
      final Map<String, dynamic> m => m,
      final List<dynamic> l when l.isNotEmpty =>
        l.first as Map<String, dynamic>,
      _ => null,
    };
    final List<dynamic> respuestas =
        (f['respuestas'] as List<dynamic>?) ?? const <dynamic>[];
    return ChecklistViaje(
      id: f['id'] as String,
      viajeId: f['viaje_id'] as String,
      fechaHora: DateTime.parse(f['fecha_hora'] as String).toLocal(),
      resultado: ResultadoChecklist.desdeCodigo(f['resultado'] as String),
      observaciones: f['observaciones'] as String?,
      fallas: respuestas
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> r) => r['estado'] == 'FALLA')
          .map(
            (Map<String, dynamic> r) => FallaChecklist(
              nombre: (r['item'] as Map<String, dynamic>)['nombre'] as String,
              critico: r['critico'] as bool,
              observacion: r['observacion'] as String?,
            ),
          )
          .toList(),
      motivoAutorizacion: autorizacion?['motivo'] as String?,
    );
  }

  @override
  Future<List<ItemChecklist>> listarItems(TipoVehiculo tipo) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _client
          .from('checklist_item')
          .select('id, codigo, grupo, nombre, critico')
          .eq('activo', true)
          .or('aplica_tipo.is.null,aplica_tipo.eq.${tipo.codigo}')
          .order('orden');
      return filas
          .map(
            (Map<String, dynamic> f) => ItemChecklist(
              id: f['id'] as String,
              codigo: f['codigo'] as String,
              grupo: f['grupo'] as String,
              nombre: f['nombre'] as String,
              critico: f['critico'] as bool,
            ),
          )
          .toList();
    });
  }

  @override
  Future<ChecklistViaje> registrar({
    required String viajeId,
    required List<ItemChecklist> items,
    required List<RespuestaChecklist> respuestas,
    String? observaciones,
  }) {
    return ejecutarCatalogo(() async {
      // El servidor exige todos los ítems: los no marcados van como OK.
      final Map<String, RespuestaChecklist> porItem =
          <String, RespuestaChecklist>{
            for (final RespuestaChecklist r in respuestas) r.itemId: r,
          };
      await _client.rpc<Map<String, dynamic>>(
        'checklist_registrar',
        params: <String, dynamic>{
          'p_viaje_id': viajeId,
          'p_respuestas': <Map<String, dynamic>>[
            for (final ItemChecklist item in items)
              <String, dynamic>{
                'item_id': item.id,
                'estado': (porItem[item.id]?.falla ?? false) ? 'FALLA' : 'OK',
                'observacion': porItem[item.id]?.observacion,
              },
          ],
          'p_observaciones': observaciones,
        },
      );
      final ChecklistViaje? creado = await _ultimo(viajeId);
      return creado!;
    });
  }

  Future<ChecklistViaje?> _ultimo(String viajeId) async {
    final List<Map<String, dynamic>> filas = await _client
        .from('checklist_viaje')
        .select(_columnas)
        .eq('viaje_id', viajeId)
        .order('fecha_hora', ascending: false)
        .limit(1);
    return filas.isEmpty ? null : aEntidad(filas.first);
  }

  @override
  Future<ChecklistViaje?> ultimoDelViaje(String viajeId) {
    return ejecutarCatalogo(() => _ultimo(viajeId));
  }

  @override
  Future<void> autorizarSalida({
    required String viajeId,
    required String motivo,
  }) {
    return ejecutarCatalogo(() async {
      await _client.rpc<Map<String, dynamic>>(
        'checklist_autorizar_salida',
        params: <String, dynamic>{'p_viaje_id': viajeId, 'p_motivo': motivo},
      );
    });
  }
}
