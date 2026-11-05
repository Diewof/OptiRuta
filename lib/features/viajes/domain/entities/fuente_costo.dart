/// Origen de un costo de viaje. Fuente de verdad: CHECK de
/// `public.costo_viaje.fuente`.
enum FuenteCosto {
  automatico('AUTOMATICO', 'Automático'),
  manual('MANUAL', 'Manual');

  const FuenteCosto(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static FuenteCosto desdeCodigo(String valor) {
    return switch (valor) {
      'AUTOMATICO' => FuenteCosto.automatico,
      'MANUAL' => FuenteCosto.manual,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Fuente de costo no válida',
      ),
    };
  }
}
