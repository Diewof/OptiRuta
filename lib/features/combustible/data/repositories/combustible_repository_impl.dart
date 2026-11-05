import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/rendimiento_combustible.dart';
import '../../domain/repositories/combustible_repository.dart';
import '../datasources/combustible_remote_data_source.dart';

class CombustibleRepositoryImpl implements CombustibleRepository {
  CombustibleRepositoryImpl(this._remote);

  final CombustibleRemoteDataSource _remote;

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  @override
  Future<void> registrarTanqueo({
    required String viajeId,
    required double galones,
    required double valor,
  }) {
    return ejecutarCatalogo(
      () => _remote.registrarTanqueo(
        viajeId: viajeId,
        galones: galones,
        valor: valor,
      ),
    );
  }

  @override
  Future<List<RendimientoCombustible>> rendimiento({
    required DateTime desde,
    required DateTime hasta,
    required DimensionCombustible dimension,
  }) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.rendimiento(
        desde: desde,
        hasta: hasta,
        dimension: dimension.codigo,
      );
      return filas
          .map(
            (Map<String, dynamic> f) => RendimientoCombustible(
              clave: f['clave'] as String,
              viajes: f['viajes'] as int,
              km: _num(f['km']),
              galones: _num(f['galones']),
              kmPorGalon: _num(f['km_por_galon']),
              kmPorGalonPrevio: (f['km_por_galon_previo'] as num?)?.toDouble(),
              variacionPct: (f['variacion_pct'] as num?)?.toDouble(),
              referenciaKmGalon: (f['referencia_km_galon'] as num?)?.toDouble(),
              alerta: f['alerta'] as bool? ?? false,
            ),
          )
          .toList();
    });
  }
}
