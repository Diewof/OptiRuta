import '../../../../core/error/catalogo_failure.dart';
import '../../domain/repositories/notificacion_repository.dart';
import '../datasources/notificacion_remote_data_source.dart';
import '../models/notificacion_model.dart';

class NotificacionRepositoryImpl implements NotificacionRepository {
  NotificacionRepositoryImpl(this._remote);

  final NotificacionRemoteDataSource _remote;

  @override
  Future<PaginaNotificaciones> listar({
    required int pagina,
    required int tamano,
  }) {
    return ejecutarCatalogo(() async {
      final List<Map<String, dynamic>> filas = await _remote.listar(
        pagina: pagina,
        tamano: tamano,
      );
      final bool hayMas = filas.length > tamano;
      final List<Map<String, dynamic>> filasPagina = hayMas
          ? filas.sublist(0, tamano)
          : filas;
      return PaginaNotificaciones(
        notificaciones: filasPagina.map(NotificacionModel.aEntidad).toList(),
        hayMas: hayMas,
      );
    });
  }

  @override
  Future<void> marcarLeida(String id) {
    return ejecutarCatalogo(() => _remote.marcarLeida(id));
  }

  @override
  Future<void> marcarTodasLeidas() {
    return ejecutarCatalogo(() => _remote.marcarTodasLeidas());
  }
}
