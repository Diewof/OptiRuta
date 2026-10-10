import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/conductor.dart';
import '../../domain/entities/tipo_pago.dart';
import '../../domain/entities/usuario_disponible.dart';
import '../../domain/repositories/conductor_repository.dart';
import '../datasources/conductor_remote_data_source.dart';
import '../models/conductor_model.dart';
import '../models/usuario_disponible_model.dart';

class ConductorRepositoryImpl implements ConductorRepository {
  ConductorRepositoryImpl(this._remote);

  final ConductorRemoteDataSource _remote;

  @override
  Future<PaginaConductores> listar({required int pagina, required int tamano}) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listar(
        pagina: pagina,
        tamano: tamano,
      );
      final bool hayMas = filas.length > tamano;
      final List<Map<String, dynamic>> filasPagina = hayMas
          ? filas.sublist(0, tamano)
          : filas;
      return PaginaConductores(
        conductores: filasPagina.map(ConductorModel.aEntidad).toList(),
        hayMas: hayMas,
      );
    });
  }

  @override
  Future<Conductor?> obtenerPropio(String usuarioId) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic>? fila = await _remote.obtenerPropio(usuarioId);
      return fila == null ? null : ConductorModel.aEntidad(fila);
    });
  }

  @override
  Future<List<UsuarioDisponible>> listarUsuariosDisponibles() {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote
          .listarUsuariosDisponibles();
      return filas.map(UsuarioDisponibleModel.aEntidad).toList();
    });
  }

  @override
  Future<Conductor> crear({
    required String usuarioId,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.crear(<String, dynamic>{
        'usuario_id': usuarioId,
        ...ConductorModel.aFila(
          licencia: licencia,
          fechaVencimientoLicencia: fechaVencimientoLicencia,
          tipoPago: tipoPago,
          porcentajeComision: porcentajeComision,
          sueldoBase: sueldoBase,
        ),
      });
      return ConductorModel.aEntidad(fila);
    });
  }

  @override
  Future<Conductor> actualizar({
    required String id,
    required String licencia,
    required DateTime fechaVencimientoLicencia,
    required TipoPago tipoPago,
    required double porcentajeComision,
    required double sueldoBase,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.actualizar(
        id,
        ConductorModel.aFila(
          licencia: licencia,
          fechaVencimientoLicencia: fechaVencimientoLicencia,
          tipoPago: tipoPago,
          porcentajeComision: porcentajeComision,
          sueldoBase: sueldoBase,
        ),
      );
      return ConductorModel.aEntidad(fila);
    });
  }

  @override
  Future<void> inhabilitar(String id) {
    return ejecutarCatalogo(() => _remote.inhabilitar(id));
  }
}
