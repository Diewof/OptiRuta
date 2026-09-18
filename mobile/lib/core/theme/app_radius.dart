import 'package:flutter/painting.dart';

/// Radios "ligeramente redondeado, no pill". Máximo 8.
abstract final class AppRadius {
  static const double sm = 4; // badges, chips
  static const double md = 6; // botones, inputs
  static const double lg = 8; // cards, hojas, diálogos

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}
