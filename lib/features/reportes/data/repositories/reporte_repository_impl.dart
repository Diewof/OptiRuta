import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/reporte.dart';
import '../../domain/repositories/reporte_repository.dart';

/// Lee la RPC `reporte_viajes`. Los filtros viajan como parámetros `p_*`,
/// nunca como texto armado en la app.
class ReporteRepositoryImpl implements ReporteRepository {
  ReporteRepositoryImpl(this._client);

  final SupabaseClient _client;

  static String _fecha(DateTime f) => f.toIso8601String().split('T').first;

  @override
  Future<List<FilaReporte>> viajes(FiltroReporte filtro) {
    return ejecutarCatalogo(() async {
      final List<dynamic> filas = await _client.rpc(
        'reporte_viajes',
        params: <String, dynamic>{
          'p_desde': _fecha(filtro.desde),
          'p_hasta': _fecha(filtro.hasta),
          'p_cliente_id': filtro.clienteId,
          'p_conductor_id': filtro.conductorId,
          'p_vehiculo_id': filtro.vehiculoId,
          'p_ruta': filtro.ruta,
        },
      );
      return filas.cast<Map<String, dynamic>>().map(aEntidad).toList();
    });
  }

  static FilaReporte aEntidad(Map<String, dynamic> f) {
    return FilaReporte(
      viajeId: f['viaje_id'] as String,
      remision: f['remision'] as String,
      fechaCierre: DateTime.parse(f['fecha_cierre'] as String),
      ruta: f['ruta'] as String,
      cliente: f['cliente'] as String,
      conductor: f['conductor'] as String,
      placa: f['placa'] as String,
      km: (f['km'] as num).toDouble(),
      valorFlete: (f['valor_flete'] as num).toDouble(),
      costos: (f['costos'] as num).toDouble(),
      rentabilidad: (f['rentabilidad'] as num).toDouble(),
      aTiempo: f['a_tiempo'] as bool?,
    );
  }
}
