import 'package:flutter/painting.dart';

/// Radios v2 (sistema-de-diseno-v2): cercano sin perder seriedad.
abstract final class AppRadius {
  static const double sm = 6; // barras, marcas pequeñas
  static const double md = 12; // botones, campos, miniaturas, fichas de icono
  static const double lg = 16; // tarjetas
  static const double xl = 24; // hoja inferior, cabecera del conductor

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));

  /// Badges, chips y semáforo. Los botones nunca son pill.
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(999));
}
