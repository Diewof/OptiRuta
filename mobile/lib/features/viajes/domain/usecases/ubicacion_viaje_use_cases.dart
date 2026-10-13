import '../entities/coordenada.dart';
import '../repositories/ubicacion_viaje_repository.dart';

class ConsultarConsentimientoUbicacionUseCase {
  const ConsultarConsentimientoUbicacionUseCase(this._repositorio);

  final UbicacionViajeRepository _repositorio;

  Future<bool> call() => _repositorio.consentimientoVigente();
}

class ResponderConsentimientoUbicacionUseCase {
  const ResponderConsentimientoUbicacionUseCase(this._repositorio);

  final UbicacionViajeRepository _repositorio;

  Future<bool> call({required bool acepta}) =>
      _repositorio.responderConsentimiento(acepta: acepta);
}

class RegistrarUbicacionViajeUseCase {
  const RegistrarUbicacionViajeUseCase(this._repositorio);

  final UbicacionViajeRepository _repositorio;

  Future<bool> call({required String viajeId, required Coordenada posicion}) =>
      _repositorio.registrarPunto(viajeId: viajeId, posicion: posicion);
}

class ListarPuntosUbicacionUseCase {
  const ListarPuntosUbicacionUseCase(this._repositorio);

  final UbicacionViajeRepository _repositorio;

  Future<List<PuntoUbicacion>> call(String viajeId) =>
      _repositorio.listarPuntos(viajeId);
}
