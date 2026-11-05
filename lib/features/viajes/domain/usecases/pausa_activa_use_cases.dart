import '../repositories/pausa_activa_repository.dart';

class ProbarPausaActivaUseCase {
  const ProbarPausaActivaUseCase(this._repositorio);

  final PausaActivaRepository _repositorio;

  Future<void> call({required String viajeId}) =>
      _repositorio.probar(viajeId: viajeId);
}

class ConsumirPausaPruebaUseCase {
  const ConsumirPausaPruebaUseCase(this._repositorio);

  final PausaActivaRepository _repositorio;

  Future<bool> call({required String viajeId}) =>
      _repositorio.consumirPrueba(viajeId: viajeId);
}

class RegistrarPausaIgnoradaUseCase {
  const RegistrarPausaIgnoradaUseCase(this._repositorio);

  final PausaActivaRepository _repositorio;

  Future<bool> call({
    required String viajeId,
    required int minutosConduccion,
    required int minutosIgnorada,
    required bool prueba,
  }) => _repositorio.registrarIgnorada(
    viajeId: viajeId,
    minutosConduccion: minutosConduccion,
    minutosIgnorada: minutosIgnorada,
    prueba: prueba,
  );
}
