import '../entities/ajuste_viaje.dart';
import '../repositories/ajuste_viaje_repository.dart';

class RegistrarAjusteViajeUseCase {
  const RegistrarAjusteViajeUseCase(this._repositorio);

  final AjusteViajeRepository _repositorio;

  Future<AjusteViaje> call({
    required String viajeId,
    required String motivo,
    String? campoModificado,
    String? valorAnterior,
    String? valorNuevo,
  }) => _repositorio.registrar(
    viajeId: viajeId,
    motivo: motivo,
    campoModificado: campoModificado,
    valorAnterior: valorAnterior,
    valorNuevo: valorNuevo,
  );
}
