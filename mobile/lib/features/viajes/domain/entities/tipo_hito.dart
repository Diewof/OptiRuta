/// Hito registrado por el conductor. Fuente de verdad: CHECK de
/// `public.hito_viaje.tipo`.
enum TipoHito {
  salida('SALIDA', 'Salida'),
  llegadaCargue('LLEGADA_CARGUE', 'Llegada a cargue'),
  salidaConCarga('SALIDA_CON_CARGA', 'Salida con carga'),
  llegadaDestino('LLEGADA_DESTINO', 'Llegada a destino'),

  /// Opcional y posterior a la llegada: se registra con el viaje ya
  /// FINALIZADO y sirve para medir la espera de descargue.
  salidaDescargue('SALIDA_DESCARGUE', 'Salida del descargue');

  const TipoHito(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoHito desdeCodigo(String valor) {
    return switch (valor) {
      'SALIDA' => TipoHito.salida,
      'LLEGADA_CARGUE' => TipoHito.llegadaCargue,
      'SALIDA_CON_CARGA' => TipoHito.salidaConCarga,
      'LLEGADA_DESTINO' => TipoHito.llegadaDestino,
      'SALIDA_DESCARGUE' => TipoHito.salidaDescargue,
      _ => throw ArgumentError.value(valor, 'valor', 'Tipo de hito no válido'),
    };
  }
}
