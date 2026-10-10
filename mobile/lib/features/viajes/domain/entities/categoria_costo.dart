/// Categoría de un costo de viaje. Fuente de verdad: CHECK de
/// `public.costo_viaje.categoria`.
enum CategoriaCosto {
  acpm('ACPM', 'ACPM'),
  peaje('PEAJE', 'Peaje'),
  cargue('CARGUE', 'Cargue'),
  descargue('DESCARGUE', 'Descargue'),
  parqueadero('PARQUEADERO', 'Parqueadero'),
  comision('COMISION', 'Comisión'),
  aceite('ACEITE', 'Aceite'),
  lavado('LAVADO', 'Lavado'),
  engrase('ENGRASE', 'Engrase'),
  mantenimientoAmortizado(
    'MANTENIMIENTO_AMORTIZADO',
    'Mantenimiento amortizado',
  ),
  otro('OTRO', 'Otro');

  const CategoriaCosto(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static CategoriaCosto desdeCodigo(String valor) {
    return switch (valor) {
      'ACPM' => CategoriaCosto.acpm,
      'PEAJE' => CategoriaCosto.peaje,
      'CARGUE' => CategoriaCosto.cargue,
      'DESCARGUE' => CategoriaCosto.descargue,
      'PARQUEADERO' => CategoriaCosto.parqueadero,
      'COMISION' => CategoriaCosto.comision,
      'ACEITE' => CategoriaCosto.aceite,
      'LAVADO' => CategoriaCosto.lavado,
      'ENGRASE' => CategoriaCosto.engrase,
      'MANTENIMIENTO_AMORTIZADO' => CategoriaCosto.mantenimientoAmortizado,
      'OTRO' => CategoriaCosto.otro,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Categoría de costo no válida',
      ),
    };
  }
}
