import '../entities/viaje.dart';
import '../repositories/viaje_repository.dart';

const int _motivoMinimo = 5;

String _validarMotivo(String motivo) {
  final String limpio = motivo.trim();
  if (limpio.length < _motivoMinimo) {
    throw ArgumentError.value(
      motivo,
      'motivo',
      'El motivo debe tener al menos $_motivoMinimo caracteres.',
    );
  }
  return limpio;
}

class CancelarViajeUseCase {
  const CancelarViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<Viaje> call({required String viajeId, required String motivo}) =>
      _repositorio.cancelar(viajeId: viajeId, motivo: _validarMotivo(motivo));
}

class EliminarViajeUseCase {
  const EliminarViajeUseCase(this._repositorio);

  final ViajeRepository _repositorio;

  Future<void> call({required String viajeId, required String motivo}) =>
      _repositorio.eliminar(viajeId: viajeId, motivo: _validarMotivo(motivo));
}
