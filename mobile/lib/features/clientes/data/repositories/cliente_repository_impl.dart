import '../../../../core/error/catalogo_failure.dart';
import '../../domain/entities/cliente.dart';
import '../../domain/repositories/cliente_repository.dart';
import '../datasources/cliente_remote_data_source.dart';
import '../models/cliente_model.dart';

class ClienteRepositoryImpl implements ClienteRepository {
  ClienteRepositoryImpl(this._remote);

  final ClienteRemoteDataSource _remote;

  @override
  Future<PaginaClientes> listar({required int pagina, required int tamano}) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listar(
        pagina: pagina,
        tamano: tamano,
      );
      final bool hayMas = filas.length > tamano;
      final List<Map<String, dynamic>> filasPagina = hayMas
          ? filas.sublist(0, tamano)
          : filas;
      return PaginaClientes(
        clientes: filasPagina.map(ClienteModel.aEntidad).toList(),
        hayMas: hayMas,
      );
    });
  }

  @override
  Future<Cliente> crear({
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.crear(
        ClienteModel.aFila(
          nombre: nombre,
          documento: documento,
          telefono: telefono,
          correo: correo,
          direccion: direccion,
        ),
      );
      return ClienteModel.aEntidad(fila);
    });
  }

  @override
  Future<Cliente> actualizar({
    required String id,
    required String nombre,
    String? documento,
    String? telefono,
    String? correo,
    String? direccion,
  }) {
    return ejecutarCatalogo(() async {
      final Map<String, dynamic> fila = await _remote.actualizar(
        id,
        ClienteModel.aFila(
          nombre: nombre,
          documento: documento,
          telefono: telefono,
          correo: correo,
          direccion: direccion,
        ),
      );
      return ClienteModel.aEntidad(fila);
    });
  }

  @override
  Future<void> inhabilitar(String id) {
    return ejecutarCatalogo(() => _remote.inhabilitar(id));
  }
}
