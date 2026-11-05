import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/espera_cliente.dart';
import '../../domain/repositories/espera_repository.dart';
import '../datasources/espera_remote_data_source.dart';

class EsperaRepositoryImpl implements EsperaRepository {
  EsperaRepositoryImpl(this._remote);

  final EsperaRemoteDataSource _remote;

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  @override
  Future<List<EsperaCliente>> porCliente({
    required DateTime desde,
    required DateTime hasta,
  }) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.porCliente(
        desde: desde,
        hasta: hasta,
      );
      return filas
          .map(
            (Map<String, dynamic> f) => EsperaCliente(
              cliente: f['cliente'] as String,
              viajes: f['viajes'] as int,
              carguesMedidos: f['cargues_medidos'] as int,
              esperaCargueH: (f['espera_cargue_h'] as num?)?.toDouble(),
              descarguesMedidos: f['descargues_medidos'] as int,
              esperaDescargueH: (f['espera_descargue_h'] as num?)?.toDouble(),
              esperaTotalH: _num(f['espera_total_h']),
              esperaMaximaH: _num(f['espera_maxima_h']),
              viajesSobreUmbral: f['viajes_sobre_umbral'] as int,
            ),
          )
          .toList();
    });
  }
}
