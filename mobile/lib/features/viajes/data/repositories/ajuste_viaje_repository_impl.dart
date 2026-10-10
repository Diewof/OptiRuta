import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/ajuste_viaje.dart';
import '../../domain/repositories/ajuste_viaje_repository.dart';
import '../datasources/ajuste_viaje_remote_data_source.dart';
import '../models/ajuste_viaje_model.dart';

class AjusteViajeRepositoryImpl implements AjusteViajeRepository {
  AjusteViajeRepositoryImpl(this._remote);

  final AjusteViajeRemoteDataSource _remote;

  @override
  Future<List<AjusteViaje>> listarPorViaje(String viajeId) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listarPorViaje(
        viajeId,
      );
      return filas.map(AjusteViajeModel.aEntidad).toList();
    });
  }

  @override
  Future<AjusteViaje> registrar({
    required String viajeId,
    required String motivo,
    String? campoModificado,
    String? valorAnterior,
    String? valorNuevo,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.registrar(
        viajeId: viajeId,
        motivo: motivo,
        campoModificado: campoModificado,
        valorAnterior: valorAnterior,
        valorNuevo: valorNuevo,
      );
      return AjusteViajeModel.aEntidad(fila);
    });
  }
}
