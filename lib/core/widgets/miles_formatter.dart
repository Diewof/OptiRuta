import 'package:flutter/services.dart';

/// Agrupa los miles con punto mientras se escribe (`3050000` → `3.050.000`).
class MilesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final String texto = conMiles(nuevo.text.replaceAll(RegExp(r'\D'), ''));
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  /// `3050000` → `3.050.000` (recibe solo dígitos).
  static String conMiles(String digitos) => digitos.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match _) => '.',
  );
}
