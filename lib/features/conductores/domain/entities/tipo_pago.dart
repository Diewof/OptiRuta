/// Modalidad de pago del conductor. Fuente de verdad: CHECK de
/// `public.conductor.tipo_pago` en la migracion de catalogos.
enum TipoPago {
  fijo('FIJO', 'Fijo'),
  comision('COMISION', 'Comisión'),
  mixto('MIXTO', 'Mixto');

  const TipoPago(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static TipoPago desdeCodigo(String valor) {
    return switch (valor) {
      'FIJO' => TipoPago.fijo,
      'COMISION' => TipoPago.comision,
      'MIXTO' => TipoPago.mixto,
      _ => throw ArgumentError.value(valor, 'valor', 'Tipo de pago no valido'),
    };
  }
}
