import '../repositories/notificacion_repository.dart';

class MarcarTodasNotificacionesLeidasUseCase {
  const MarcarTodasNotificacionesLeidasUseCase(this._repositorio);

  final NotificacionRepository _repositorio;

  Future<void> call() => _repositorio.marcarTodasLeidas();
}
