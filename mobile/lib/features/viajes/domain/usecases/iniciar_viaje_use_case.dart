import '../entities/coordenada.dart';
import '../entities/viaje.dart';
import '../repositories/viaje_repository.dart';

class IniciarViajeUseCase {
  const IniciarViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<Viaje> call({
    required String viajeId,
    required Coordenada ubicacion,
    required DateTime fechaHora,
  }) => _repositorio.iniciar(
    viajeId: viajeId,
    ubicacion: ubicacion,
    fechaHora: fechaHora,
  );
}
