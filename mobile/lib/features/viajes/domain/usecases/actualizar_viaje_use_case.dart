import '../entities/viaje.dart';
import '../repositories/viaje_repository.dart';

/// Edita fecha de salida, peso y flete de un viaje abierto (RF-04). El
/// servidor decide si el viaje aún se puede editar.
class ActualizarViajeUseCase {
  const ActualizarViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<Viaje> call({
    required String viajeId,
    required DateTime fechaSalidaProgramada,
    required double? pesoCarga,
    required double valorFlete,
  }) {
    if (valorFlete <= 0) {
      throw ArgumentError.value(valorFlete, 'valorFlete', 'Debe ser > 0.');
    }
    if (pesoCarga != null && pesoCarga < 0) {
      throw ArgumentError.value(pesoCarga, 'pesoCarga', 'Debe ser >= 0.');
    }
    return _repositorio.actualizar(
      viajeId: viajeId,
      fechaSalidaProgramada: fechaSalidaProgramada,
      pesoCarga: pesoCarga,
      valorFlete: valorFlete,
    );
  }
}
