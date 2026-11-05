/// Una regla de validación con su etiqueta visible y su comprobación pura.
///
/// Sin estado, sin Flutter. Las reglas se muestran como lista en vivo bajo el
/// campo y también deciden si el formulario puede enviarse.
class ValidationRule {
  const ValidationRule(this.label, this.test);

  /// Texto que ve la persona, redactado en positivo ("Al menos 3 caracteres").
  final String label;

  /// `true` si [value] cumple la regla.
  final bool Function(String value) test;
}

/// Devuelve la etiqueta de la primera regla incumplida, o `null` si todas
/// pasan. Útil para el anuncio de accesibilidad y el foco al primer campo
/// inválido al enviar.
String? firstUnsatisfied(List<ValidationRule> rules, String value) {
  for (final ValidationRule rule in rules) {
    if (!rule.test(value)) return rule.label;
  }
  return null;
}

/// `true` si [value] cumple todas las reglas.
bool allSatisfied(List<ValidationRule> rules, String value) =>
    firstUnsatisfied(rules, value) == null;
