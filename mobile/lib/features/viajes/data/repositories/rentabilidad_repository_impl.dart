import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/rentabilidad_consolidada.dart';
import '../../domain/entities/rentabilidad_marginal.dart';
import '../../domain/repositories/rentabilidad_repository.dart';
import '../datasources/rentabilidad_remote_data_source.dart';
import '../models/rentabilidad_model.dart';

class RentabilidadRepositoryImpl implements RentabilidadRepository {
  RentabilidadRepositoryImpl(this._remote);

  final RentabilidadRemoteDataSource _remote;

  @override
  Future<RentabilidadMarginal> marginal(String viajeId) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.marginal(viajeId);
      return RentabilidadModel.marginalDesdeFila(fila);
    });
  }

  @override
  Future<RentabilidadConsolidada> consolidada({
    required DateTime desde,
    required DateTime hasta,
    String? clienteId,
    String? conductorId,
    String? vehiculoId,
    String? ruta,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.consolidada(
        desde: desde,
        hasta: hasta,
        clienteId: clienteId,
        conductorId: conductorId,
        vehiculoId: vehiculoId,
        ruta: ruta,
      );
      return RentabilidadModel.consolidadaDesdeFila(fila);
    });
  }
}
