import '../../../core/validation/validation_rule.dart';

/// Reglas de validación de forma para los campos de autenticación.
///
/// Redactadas en positivo para mostrarse como checklist en vivo bajo el campo.
/// La validación real vive en el backend; esto es solo guía de la interfaz.
abstract final class AuthFieldRules {
  static final RegExp _digito = RegExp('[0-9]');
  static final RegExp _soloNombre = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ '\-]+$");
  static final RegExp _mayuscula = RegExp('[A-ZÁÉÍÓÚÜÑ]');
  static final RegExp _minuscula = RegExp('[a-záéíóúüñ]');
  static final RegExp _espacio = RegExp(r'\s');

  static final List<ValidationRule> nombre = <ValidationRule>[
    ValidationRule('Al menos 3 caracteres', (String v) => v.trim().length >= 3),
    ValidationRule('Sin números', (String v) => !_digito.hasMatch(v)),
    ValidationRule(
      'Sin símbolos ni signos',
      (String v) => v.trim().isEmpty || _soloNombre.hasMatch(v.trim()),
    ),
    ValidationRule(
      'Nombre y apellido',
      (String v) =>
          v.trim().split(_espacio).where((String p) => p.isNotEmpty).length >=
          2,
    ),
  ];

  static final List<ValidationRule> correo = <ValidationRule>[
    ValidationRule(
      'Sin espacios',
      (String v) => v.isNotEmpty && !_espacio.hasMatch(v),
    ),
    ValidationRule(
      'Incluye @ y un dominio',
      (String v) => RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(v),
    ),
    ValidationRule(
      'El dominio termina en punto (ej. .com)',
      (String v) => RegExp(r'@[^@\s]+\.[^@\s]{2,}$').hasMatch(v),
    ),
  ];

  static final List<ValidationRule> contrasena = <ValidationRule>[
    ValidationRule('Al menos 8 caracteres', (String v) => v.length >= 8),
    ValidationRule('Una letra mayúscula', (String v) => _mayuscula.hasMatch(v)),
    ValidationRule('Una letra minúscula', (String v) => _minuscula.hasMatch(v)),
    ValidationRule('Un número', (String v) => _digito.hasMatch(v)),
  ];

  static List<ValidationRule> confirmarContrasena(String Function() original) {
    return <ValidationRule>[
      ValidationRule(
        'Coincide con la contraseña',
        (String v) => v.isNotEmpty && v == original(),
      ),
    ];
  }
}
