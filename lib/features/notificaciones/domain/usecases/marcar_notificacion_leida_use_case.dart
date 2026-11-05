import '../repositories/notificacion_repository.dart';

class MarcarNotificacionLeidaUseCase {
  const MarcarNotificacionLeidaUseCase(this._repositorio);

  final NotificacionRepository _repositorio;

  Future<void> call(String id) => _repositorio.marcarLeida(id);
}
