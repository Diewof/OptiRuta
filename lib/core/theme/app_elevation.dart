import 'package:flutter/painting.dart';

/// Dos niveles de elevación, nada más.
abstract final class AppElevation {
  /// Tarjetas.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0F14273F), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x1214273F), offset: Offset(0, 4), blurRadius: 14),
  ];

  /// Hoja inferior, avisos y la tarjeta de rentabilidad del dashboard.
  static const List<BoxShadow> float = <BoxShadow>[
    BoxShadow(color: Color(0x3814273F), offset: Offset(0, 8), blurRadius: 28),
  ];
}
