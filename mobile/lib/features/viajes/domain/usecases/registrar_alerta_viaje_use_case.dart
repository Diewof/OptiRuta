import '../entities/coordenada.dart';
import '../entities/tipo_alerta_viaje.dart';
import '../repositories/viaje_repository.dart';

class RegistrarAlertaViajeUseCase {
  const RegistrarAlertaViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  /// Devuelve `true` si el servidor creó la notificación para el
  /// administrador y `false` si ya había una reciente (deduplicación).
  Future<bool> call({
    required String viajeId,
    required TipoAlertaViaje tipo,
    required Coordenada ubicacion,
  }) => _repositorio.registrarAlerta(
    viajeId: viajeId,
    tipo: tipo,
    ubicacion: ubicacion,
  );
}
