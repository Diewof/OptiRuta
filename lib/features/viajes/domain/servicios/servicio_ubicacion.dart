import '../entities/coordenada.dart';

enum EstadoPermisoUbicacion {
  concedido,

  /// El usuario lo negó, pero se puede volver a pedir.
  denegado,

  /// Negado para siempre (hay que ir a los ajustes del sistema) o GPS apagado.
  bloqueado,
}

/// Fuente de la posición del dispositivo. Contrato de dominio para que el
/// cubit del mapa no dependa de `geolocator` y se pueda probar con un doble.
abstract interface class ServicioUbicacion {
  Future<EstadoPermisoUbicacion> solicitarPermiso();

  /// Una lectura puntual de la posición (p. ej. al comenzar el viaje). Lanza
  /// [Exception] si no se puede obtener a tiempo. No se guarda.
  Future<Coordenada> posicionActual();

  /// Posiciones en vivo mientras haya un oyente. No se guardan.
  Stream<Coordenada> posiciones();
}
