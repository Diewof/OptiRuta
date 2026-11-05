/// Eventos que el teléfono del conductor detecta y reporta al servidor
/// (`viaje_registrar_alerta`). Los códigos coinciden con
/// `notificacion.tipo`.
enum TipoAlertaViaje {
  paradaProlongada('PARADA_PROLONGADA', 'Llevas mucho tiempo detenido'),
  desvioRuta('DESVIO_RUTA', 'Te desviaste de la ruta estimada');

  const TipoAlertaViaje(this.codigo, this.mensaje);

  final String codigo;

  /// Texto para el conductor en el banner del mapa.
  final String mensaje;
}
