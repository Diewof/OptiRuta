import '../repositories/notificacion_repository.dart';

class ListarNotificacionesUseCase {
  const ListarNotificacionesUseCase(this._repositorio);

  final NotificacionRepository _repositorio;

  Future<PaginaNotificaciones> call({required int pagina, int tamano = 20}) =>
      _repositorio.listar(pagina: pagina, tamano: tamano);
}
