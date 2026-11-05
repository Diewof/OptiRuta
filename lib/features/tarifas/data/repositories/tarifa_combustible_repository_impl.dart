import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/tarifa_combustible.dart';
import '../../domain/repositories/tarifa_combustible_repository.dart';
import '../datasources/tarifa_combustible_remote_data_source.dart';

class TarifaCombustibleRepositoryImpl implements TarifaCombustibleRepository {
  TarifaCombustibleRepositoryImpl(this._remote);

  final TarifaCombustibleRemoteDataSource _remote;

  static TarifaCombustible _aEntidad(Map<String, dynamic> fila) {
    return TarifaCombustible(
      id: fila['id'] as String,
      ciudad: fila['ciudad'] as String,
      precioGalon: (fila['precio_galon'] as num).toDouble(),
      fechaVigenciaDesde: DateTime.parse(
        fila['fecha_vigencia_desde'] as String,
      ),
      automatica: fila['fuente'] == 'AUTOMATICO',
    );
  }

  @override
  Future<List<TarifaCombustible>> listar() {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listar();
      return filas.map(_aEntidad).toList();
    });
  }

  @override
  Future<TarifaCombustible> registrar({
    required String ciudad,
    required double precioGalon,
    required DateTime fechaVigenciaDesde,
  }) async {
    try {
      return await ejecutarCatalogo(() async {
        final Map<String, dynamic> fila = await _remote.crear(<String, dynamic>{
          'ciudad': ciudad,
          'precio_galon': precioGalon,
          'fecha_vigencia_desde': fechaVigenciaDesde
              .toIso8601String()
              .split('T')
              .first,
          'fuente': 'MANUAL',
        });
        return _aEntidad(fila);
      });
    } on CatalogoFailure catch (falla) {
      if (falla.codigo == CatalogoErrorCodigo.yaExiste) {
        throw CatalogoFailure.yaExiste(
          'Ya hay una tarifa para esa ciudad y fecha. Edita su precio.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<TarifaCombustible> actualizarPrecio({
    required String id,
    required double precioGalon,
  }) {
    return ejecutarCatalogo(() async {
      return _aEntidad(await _remote.actualizarPrecio(id, precioGalon));
    });
  }
}
