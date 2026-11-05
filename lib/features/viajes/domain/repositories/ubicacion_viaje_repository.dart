import '../entities/coordenada.dart';

/// Un punto de ubicación registrado durante un viaje (RF-21).
class PuntoUbicacion {
  const PuntoUbicacion({required this.posicion, required this.fechaHora});

  final Coordenada posicion;
  final DateTime fechaHora;
}

/// Registro periódico de ubicación con consentimiento (RF-21/23). Escribe el
/// conductor vía RPC; lee el administrador (y el conductor sus propios viajes).
abstract interface class UbicacionViajeRepository {
  /// `true` si el conductor autenticado aceptó el registro de su ubicación.
  Future<bool> consentimientoVigente();

  /// Acepta o revoca el consentimiento. Devuelve el estado resultante.
  Future<bool> responderConsentimiento({required bool acepta});

  /// Devuelve `true` si el servidor guardó el punto (puede descartarlo si hay
  /// otro reciente).
  Future<bool> registrarPunto({
    required String viajeId,
    required Coordenada posicion,
  });

  /// Puntos del viaje, del más reciente al más antiguo.
  Future<List<PuntoUbicacion>> listarPuntos(String viajeId);
}
