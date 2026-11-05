import '../entities/ajuste_viaje.dart';
import '../repositories/ajuste_viaje_repository.dart';

class RegistrarAjusteViajeUseCase {
  const RegistrarAjusteViajeUseCase(this._repositorio);

  final AjusteViajeRepository _repositorio;

  Future<AjusteViaje> call({
    required String viajeId,
    required String motivo,
    required String concepto,
    required double valorNuevo,
  }) => _repositorio.registrar(
    viajeId: viajeId,
    motivo: motivo,
    concepto: concepto,
    valorNuevo: valorNuevo,
  );
}
