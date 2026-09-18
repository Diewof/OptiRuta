import 'package:flutter/painting.dart';

/// Sombras. Un solo token de card y uno de overlay. Nada más.
abstract final class AppElevation {
  /// y=1, blur=3, color=#14273F @ 8%.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x1414273F), offset: Offset(0, 1), blurRadius: 3),
  ];

  /// y=4, blur=12, color=#14273F @ 12%.
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(color: Color(0x1F14273F), offset: Offset(0, 4), blurRadius: 12),
  ];
}
