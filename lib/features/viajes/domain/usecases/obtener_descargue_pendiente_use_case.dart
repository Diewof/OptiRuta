import '../entities/descargue_pendiente.dart';
import '../repositories/hito_repository.dart';

class ObtenerDescarguePendienteUseCase {
  const ObtenerDescarguePendienteUseCase(this._repositorio);

  final HitoRepository _repositorio;

  Future<DescarguePendiente?> call() => _repositorio.descarguePendiente();
}
