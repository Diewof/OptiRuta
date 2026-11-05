/// Kilómetros con separador de miles de punto y sin decimales: `12.450 km`.
String formatearKm(double km) {
  final String digitos = km.round().abs().toString();
  final StringBuffer salida = StringBuffer(km < 0 ? '-' : '');
  for (int i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) salida.write('.');
    salida.write(digitos[i]);
  }
  return '$salida km';
}
