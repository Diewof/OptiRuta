/// Formatea una fecha como `dd/MM/yyyy` sin depender de `intl` (unico
/// formato de fecha que necesita la app por ahora).
String formatearFecha(DateTime fecha) {
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year}';
}

const List<String> _mesesCortosEs = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formatea una fecha/hora como `24 sep, 18:40`, para hitos y planilla de
/// viaje (sin depender de `intl`, mismo criterio que [formatearFecha]).
String formatearFechaHoraCorta(DateTime fecha) {
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  final String mes = _mesesCortosEs[fecha.month - 1];
  return '${fecha.day} $mes, ${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
}

/// Formatea solo la hora como `HH:mm` (hitos del conductor).
String formatearHora(DateTime fecha) {
  String dosDigitos(int n) => n.toString().padLeft(2, '0');
  return '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
}
