import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/metricas.dart';
import '../../domain/repositories/metricas_repository.dart';
import '../datasources/metricas_remote_data_source.dart';

class MetricasRepositoryImpl implements MetricasRepository {
  MetricasRepositoryImpl(this._remote);

  final MetricasRemoteDataSource _remote;

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  @override
  Future<MetricasPeriodo> periodo({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> f = await _remote.periodo(
        desde: desde,
        hasta: hasta,
        clienteId: clienteId,
        conductorId: conductorId,
        vehiculoId: vehiculoId,
        ruta: ruta,
      );
      return MetricasPeriodo(
        viajesCerrados: f['viajes_cerrados'] as int,
        kmTotal: _num(f['km_total']),
        costosDirectos: _num(f['costos_directos']),
        costoPorKm: (f['costo_por_km'] as num?)?.toDouble(),
        viajesATiempo: f['viajes_a_tiempo'] as int,
        viajesMedidos: f['viajes_medidos'] as int,
        utilizacionFlotaPct: _num(f['utilizacion_flota_pct']),
      );
    });
  }

  @override
  Future<List<MetricaDimension>> porDimension({
    required DateTime desde,
    required DateTime hasta,
    required DimensionMetrica dimension,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.porDimension(
        desde: desde,
        hasta: hasta,
        dimension: dimension.codigo,
        clienteId: clienteId,
        conductorId: conductorId,
        vehiculoId: vehiculoId,
        ruta: ruta,
      );
      return filas
          .map(
            (Map<String, dynamic> f) => MetricaDimension(
              clave: f['clave'] as String,
              viajes: f['viajes'] as int,
              totalFlete: _num(f['total_flete']),
              totalCostos: _num(f['total_costos']),
              rentabilidad: _num(f['rentabilidad']),
              kmTotal: _num(f['km_total']),
              viajesATiempo: f['viajes_a_tiempo'] as int,
              viajesMedidos: f['viajes_medidos'] as int,
            ),
          )
          .toList();
    });
  }
}
