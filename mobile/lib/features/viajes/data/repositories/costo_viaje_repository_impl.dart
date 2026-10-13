import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/repositories/costo_viaje_repository.dart';
import '../datasources/costo_viaje_remote_data_source.dart';
import '../models/costo_viaje_model.dart';

class CostoViajeRepositoryImpl implements CostoViajeRepository {
  CostoViajeRepositoryImpl(this._remote);

  final CostoViajeRemoteDataSource _remote;

  @override
  Future<List<CostoViaje>> listarPorViaje(String viajeId) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listarPorViaje(
        viajeId,
      );
      return filas.map(CostoViajeModel.aEntidad).toList();
    });
  }

  @override
  Future<CostoViaje> agregarOtro({
    required String viajeId,
    required String descripcion,
    double valorEstimado = 0,
    double? valorReal,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.agregarOtro(
        viajeId: viajeId,
        descripcion: descripcion,
        valorEstimado: valorEstimado,
        valorReal: valorReal,
      );
      return CostoViajeModel.aEntidad(fila);
    });
  }

  @override
  Future<CostoViaje> actualizarEstimado({
    required String costoId,
    required double valorEstimado,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.actualizarEstimado(
        costoId: costoId,
        valorEstimado: valorEstimado,
      );
      return CostoViajeModel.aEntidad(fila);
    });
  }

  @override
  Future<CostoViaje> actualizarValorReal({
    required String costoId,
    required double valorReal,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.actualizarValorReal(
        costoId: costoId,
        valorReal: valorReal,
      );
      return CostoViajeModel.aEntidad(fila);
    });
  }
}
