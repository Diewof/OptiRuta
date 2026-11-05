/// Tipos de vehiculo de la flota. Fuente de verdad: CHECK de
/// `public.vehiculo.tipo` en la migracion de catalogos.
enum TipoVehiculo {
  dobleTroque('DOBLE_TROQUE', 'Doble troque'),
  mula('MULA', 'Mula');

  const TipoVehiculo(this.codigo, this.etiqueta);

  /// Valor tal cual viaja en la columna `vehiculo.tipo`.
  final String codigo;

  /// Texto legible para la UI.
  final String etiqueta;

  static TipoVehiculo desdeCodigo(String valor) {
    return switch (valor) {
      'DOBLE_TROQUE' => TipoVehiculo.dobleTroque,
      'MULA' => TipoVehiculo.mula,
      _ => throw ArgumentError.value(
        valor,
        'valor',
        'Tipo de vehiculo no valido',
      ),
    };
  }
}
