/// Tipo de notificación. Fuente de verdad: CHECK de `public.notificacion.tipo`
/// en la migración `notificacion`.
enum TipoNotificacion {
  documentoPorVencer('DOCUMENTO_POR_VENCER', 'Documento por vencer'),
  retraso('RETRASO', 'Retraso en viaje'),
  viajeCompletado('VIAJE_COMPLETADO', 'Viaje completado'),
  peajeRegistrado('PEAJE_REGISTRADO', 'Peajes registrados'),
  novedad('NOVEDAD', 'Novedad reportada'),
  paradaProlongada('PARADA_PROLONGADA', 'Parada prolongada'),
  desvioRuta('DESVIO_RUTA', 'Desvío de ruta');

  const TipoNotificacion(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Alertas que el teléfono del conductor detecta en ruta: llevan la
  /// ubicación del evento y se pueden ver en el mapa del viaje.
  bool get esAlertaDeRuta =>
      this == TipoNotificacion.paradaProlongada ||
      this == TipoNotificacion.desvioRuta;

  static TipoNotificacion desdeCodigo(String valor) {
    return switch (valor) {
      'DOCUMENTO_POR_VENCER' => TipoNotificacion.documentoPorVencer,
      'RETRASO' => TipoNotificacion.retraso,
      'VIAJE_COMPLETADO' => TipoNotificacion.viajeCompletado,
      'PEAJE_REGISTRADO' => TipoNotificacion.peajeRegistrado,
      'NOVEDAD' => TipoNotificacion.novedad,
      'PARADA_PROLONGADA' => TipoNotificacion.paradaProlongada,
      'DESVIO_RUTA' => TipoNotificacion.desvioRuta,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Tipo de notificación no válido',
      ),
    };
  }
}
