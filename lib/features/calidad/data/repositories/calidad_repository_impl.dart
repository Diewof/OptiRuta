import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/calidad.dart';
import '../../domain/repositories/calidad_repository.dart';

/// Lee las RPC de calidad. Los filtros viajan como parámetros `p_*`.
class CalidadRepositoryImpl implements CalidadRepository {
  CalidadRepositoryImpl(this._client);

  final SupabaseClient _client;

  static String _fecha(DateTime f) => f.toIso8601String().split('T').first;

  static double? _numNulo(Object? v) => (v as num?)?.toDouble();

  static Map<String, dynamic> _filtros(FiltroReporte f) => <String, dynamic>{
    'p_desde': _fecha(f.desde),
    'p_hasta': _fecha(f.hasta),
    'p_cliente_id': f.clienteId,
    'p_conductor_id': f.conductorId,
    'p_vehiculo_id': f.vehiculoId,
    'p_ruta': f.ruta,
  };

  @override
  Future<CalidadViaje?> calidadDeViaje(String viajeId) {
    return ejecutarCatalogo(() async {
      final List<dynamic> filas = await _client.rpc(
        'viaje_calidad',
        params: <String, dynamic>{'p_viaje_id': viajeId},
      );
      // La RPC no devuelve filas mientras el viaje no esté finalizado.
      if (filas.isEmpty) return null;
      final Map<String, dynamic> f = filas.first as Map<String, dynamic>;
      return CalidadViaje(
        puntualidad: NivelCalidad.desdeCodigo(
          f['puntualidad_nivel'] as String?,
        ),
        minutosRetraso: _numNulo(f['minutos_retraso']),
        rentabilidad: NivelCalidad.desdeCodigo(
          f['rentabilidad_nivel'] as String?,
        ),
        desvioCostosPct: _numNulo(f['desvio_costos_pct']),
        categoriaMayorDesvio: f['categoria_mayor_desvio'] as String?,
        satisfaccion: NivelCalidad.desdeCodigo(
          f['satisfaccion_nivel'] as String?,
        ),
        csatPromedio: _numNulo(f['csat_promedio']),
        incidencias: NivelCalidad.desdeCodigo(
          f['incidencias_nivel'] as String?,
        ),
        incidenciasTotal: (f['incidencias_total'] as int?) ?? 0,
        puntaje: _numNulo(f['puntaje']),
        nivel: NivelCalidad.desdeCodigo(f['nivel'] as String?),
      );
    });
  }

  static ResumenCalidad _resumenDeFila(Map<String, dynamic> f) {
    return ResumenCalidad(
      viajesEvaluados: f['viajes_evaluados'] as int,
      verdes: f['verdes'] as int,
      ambares: f['ambares'] as int,
      rojos: f['rojos'] as int,
      puntajePromedio: _numNulo(f['puntaje_promedio']),
      puntualidadRojos: f['puntualidad_rojos'] as int,
      rentabilidadRojos: f['rentabilidad_rojos'] as int,
      satisfaccionRojos: f['satisfaccion_rojos'] as int,
      incidenciasRojos: f['incidencias_rojos'] as int,
    );
  }

  @override
  Future<ResumenCalidad> resumen(FiltroReporte filtro) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> f = await _client
          .rpc('calidad_resumen', params: _filtros(filtro))
          .single();
      return _resumenDeFila(f);
    });
  }

  @override
  Future<ResumenCalidad> resumenDeConductor(
    String conductorId,
    DateTime desde,
    DateTime hasta,
  ) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> f = await _client
          .rpc(
            'conductor_calidad',
            params: <String, dynamic>{
              'p_conductor_id': conductorId,
              'p_desde': _fecha(desde),
              'p_hasta': _fecha(hasta),
            },
          )
          .single();
      return _resumenDeFila(f);
    });
  }

  @override
  Future<List<CalidadDimension>> porDimension(
    FiltroReporte filtro,
    DimensionCalidad dimension,
  ) {
    return ejecutarCatalogo(() async {
      final List<dynamic> filas = await _client.rpc(
        'calidad_por_dimension',
        params: <String, dynamic>{
          'p_desde': _fecha(filtro.desde),
          'p_hasta': _fecha(filtro.hasta),
          'p_dimension': dimension.codigo,
          'p_cliente_id': filtro.clienteId,
          'p_conductor_id': filtro.conductorId,
          'p_vehiculo_id': filtro.vehiculoId,
          'p_ruta': filtro.ruta,
        },
      );
      return filas
          .cast<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> f) => CalidadDimension(
              clave: f['clave'] as String,
              viajes: f['viajes'] as int,
              puntajePromedio: _numNulo(f['puntaje_promedio']),
              rojos: f['rojos'] as int,
              puntualidadRojos: f['puntualidad_rojos'] as int,
              rentabilidadRojos: f['rentabilidad_rojos'] as int,
              satisfaccionRojos: f['satisfaccion_rojos'] as int,
              incidenciasRojos: f['incidencias_rojos'] as int,
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<AlertaRecurrente>> recurrentes(FiltroReporte filtro) {
    return ejecutarCatalogo(() async {
      final List<dynamic> filas = await _client.rpc(
        'calidad_recurrentes',
        params: <String, dynamic>{
          'p_desde': _fecha(filtro.desde),
          'p_hasta': _fecha(filtro.hasta),
        },
      );
      return filas
          .cast<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> f) => AlertaRecurrente(
              entidad: f['entidad'] as String,
              clave: f['clave'] as String,
              dimension: f['dimension'] as String,
              viajes: f['viajes'] as int,
            ),
          )
          .toList();
    });
  }
}
