import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/vehiculo.dart';
import '../../domain/repositories/vehiculo_repository.dart';
import '../datasources/vehiculo_remote_data_source.dart';
import '../models/vehiculo_model.dart';

class VehiculoRepositoryImpl implements VehiculoRepository {
  VehiculoRepositoryImpl(this._remote);

  final VehiculoRemoteDataSource _remote;

  @override
  Future<PaginaVehiculos> listar({required int pagina, required int tamano}) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listar(
        pagina: pagina,
        tamano: tamano,
      );
      final bool hayMas = filas.length > tamano;
      final List<Map<String, dynamic>> filasPagina = hayMas
          ? filas.sublist(0, tamano)
          : filas;
      return PaginaVehiculos(
        vehiculos: filasPagina.map(VehiculoModel.aEntidad).toList(),
        hayMas: hayMas,
      );
    });
  }

  @override
  Future<Vehiculo> crear({
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.crear(
        VehiculoModel.aFila(
          placa: placa,
          tipo: tipo,
          capacidadCarga: capacidadCarga,
          rendimientoKmGalon: rendimientoKmGalon,
        ),
      );
      return VehiculoModel.aEntidad(fila);
    });
  }

  @override
  Future<Vehiculo> actualizar({
    required String id,
    required String placa,
    required TipoVehiculo tipo,
    required double capacidadCarga,
    required double rendimientoKmGalon,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.actualizar(
        id,
        VehiculoModel.aFila(
          placa: placa,
          tipo: tipo,
          capacidadCarga: capacidadCarga,
          rendimientoKmGalon: rendimientoKmGalon,
        ),
      );
      return VehiculoModel.aEntidad(fila);
    });
  }

  @override
  Future<void> inhabilitar(String id) {
    return ejecutarCatalogo(() => _remote.inhabilitar(id));
  }
}
