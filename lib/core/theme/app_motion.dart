import 'package:flutter/widgets.dart';

/// Catálogo de movimiento (sistema-de-diseno-v2 §2.4). Todo movimiento tiene
/// función y nunca bloquea el registro del conductor.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  /// Solo el conteo de la cifra de rentabilidad, una vez por carga.
  static const Duration count = Duration(milliseconds: 600);

  static const Curve easeOut = Cubic(.2, .8, .2, 1);
  static const Curve easeInOut = Cubic(.4, 0, .2, 1);

  /// Retardo entre elementos de una lista (máx. 5 elementos).
  static const Duration stagger = Duration(milliseconds: 40);

  /// `true` si el usuario pidió "reducir movimiento" (el cambio es instantáneo).
  static bool reducir(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Duración efectiva: cero con "reducir movimiento".
  static Duration efectiva(BuildContext context, Duration d) =>
      reducir(context) ? Duration.zero : d;
}
