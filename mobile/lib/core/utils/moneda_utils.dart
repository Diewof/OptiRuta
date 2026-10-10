/// Formateo simple de pesos colombianos sin depender de `intl` (mismo
/// criterio que `fecha_utils.dart`): separador de miles con punto, sin
/// decimales.
class NumberFormatCop {
  String formatear(double valor) {
    final String entero = valor.round().abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(entero[i]);
    }
    return '${valor < 0 ? '-' : ''}\$$buffer';
  }
}

/// Formato compacto en millones con coma decimal: `$ 18,4 M`, `−$ 4,8 M`.
String formatearMillones(double valor, {int decimales = 1}) {
  final String cifra = (valor.abs() / 1e6)
      .toStringAsFixed(decimales)
      .replaceAll('.', ',');
  return '${valor < 0 ? '−' : ''}\$ $cifra M';
}

/// Porcentaje con coma decimal: `21,3 %`, `−6,7 %`.
String formatearPorcentaje(double valor) {
  final String cifra = valor.abs().toStringAsFixed(1).replaceAll('.', ',');
  return '${valor < 0 ? '−' : ''}$cifra %';
}
