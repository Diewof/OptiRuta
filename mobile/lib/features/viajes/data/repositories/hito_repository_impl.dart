import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';
import '../../domain/repositories/hito_repository.dart';
import '../datasources/hito_remote_data_source.dart';
import '../models/hito_model.dart';

class HitoRepositoryImpl implements HitoRepository {
  HitoRepositoryImpl(this._remote);

  final HitoRemoteDataSource _remote;

  @override
  Future<List<Hito>> listarPorViaje(String viajeId) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listarPorViaje(
        viajeId,
      );
      return filas.map(HitoModel.aEntidad).toList();
    });
  }

  @override
  Future<Hito> registrar({
    required String viajeId,
    required TipoHito tipo,
    required DateTime fechaHora,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.registrar(
        viajeId: viajeId,
        tipo: tipo.codigo,
        fechaHora: fechaHora,
      );
      return HitoModel.aEntidad(fila);
    });
  }
}
