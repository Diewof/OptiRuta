import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../../dashboard/domain/entities/metricas.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../domain/entities/satisfaccion.dart';
import '../../domain/repositories/satisfaccion_repository.dart';

/// Lee las RPC `satisfaccion_*`. Los filtros viajan como parámetros `p_*`.
class SatisfaccionRepositoryImpl implements SatisfaccionRepository {
  SatisfaccionRepositoryImpl(this._client);

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
  Future<ResumenSatisfaccion> resumen(FiltroReporte filtro) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> f = await _client
          .rpc('satisfaccion_resumen', params: _filtros(filtro))
          .single();
      return ResumenSatisfaccion(
        encuestasTotal: f['encuestas_total'] as int,
        respondidas: f['respondidas'] as int,
        pendientes: f['pendientes'] as int,
        sinContacto: f['sin_contacto'] as int,
        vencidas: f['vencidas'] as int,
        csatEntrega: _numNulo(f['csat_entrega']),
        csatServicio: _numNulo(f['csat_servicio']),
        csatAtencion: _numNulo(f['csat_atencion']),
        csatPuntualidad: _numNulo(f['csat_puntualidad']),
        csatGlobal: _numNulo(f['csat_global']),
        nps: _numNulo(f['nps']),
        promotores: f['promotores'] as int,
        pasivos: f['pasivos'] as int,
        detractores: f['detractores'] as int,
        viajesMedidos: f['viajes_medidos'] as int,
        viajesATiempo: f['viajes_a_tiempo'] as int,
        puntualidadPercibida: f['puntualidad_percibida'] as int,
      );
    });
  }

  @override
  Future<List<SatisfaccionDimension>> porDimension(
    FiltroReporte filtro,
    DimensionMetrica dimension,
  ) {
    return ejecutarCatalogo(() async {
      final List<dynamic> filas = await _client.rpc(
        'satisfaccion_por_dimension',
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
            (Map<String, dynamic> f) => SatisfaccionDimension(
              clave: f['clave'] as String,
              respondidas: f['respondidas'] as int,
              csatGlobal: _numNulo(f['csat_global']),
              nps: _numNulo(f['nps']),
            ),
          )
          .toList();
    });
  }

  @override
  Future<List<ComentarioSatisfaccion>> comentarios(
    FiltroReporte filtro, {
    int limite = 20,
  }) {
    return ejecutarCatalogo(() async {
      final List<dynamic> filas = await _client.rpc(
        'satisfaccion_comentarios',
        params: <String, dynamic>{..._filtros(filtro), 'p_limite': limite},
      );
      return filas
          .cast<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> f) => ComentarioSatisfaccion(
              fechaRespuesta: DateTime.parse(f['fecha_respuesta'] as String)
                  .toLocal(),
              cliente: f['cliente'] as String,
              conductor: f['conductor'] as String,
              ruta: f['ruta'] as String,
              csatGlobal: (f['csat_global'] as num).toDouble(),
              nps: f['nps'] as int,
              comentario: f['comentario'] as String,
            ),
          )
          .toList();
    });
  }

  @override
  Future<EncuestaViaje?> encuestaDeViaje(String viajeId) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic>? f = await _client
          .from('encuesta_satisfaccion')
          .select(
            'estado, enlace, destinatario, nps, csat_entrega, csat_servicio, '
            'csat_atencion, csat_puntualidad',
          )
          .eq('viaje_id', viajeId)
          .maybeSingle();
      if (f == null) return null;
      final List<num?> csat = <num?>[
        f['csat_entrega'] as num?,
        f['csat_servicio'] as num?,
        f['csat_atencion'] as num?,
        f['csat_puntualidad'] as num?,
      ];
      return EncuestaViaje(
        estado: EstadoEncuesta.desdeCodigo(f['estado'] as String),
        enlace: f['enlace'] as String?,
        destinatario: f['destinatario'] as String?,
        nps: f['nps'] as int?,
        csatGlobal: csat.any((num? v) => v == null)
            ? null
            : csat.fold<double>(0, (double a, num? v) => a + v!) / 4,
      );
    });
  }
}
