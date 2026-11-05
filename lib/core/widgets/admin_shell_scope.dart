import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'admin_section.dart';

/// Lo que el shell del Administrador ofrece a las pantallas que aloja:
/// cambiar de sección sin destruirlas y el contador de notificaciones.
class AdminShellScope extends InheritedWidget {
  const AdminShellScope({
    required this.irA,
    required this.volver,
    required this.puedeVolver,
    required this.noLeidas,
    required this.actual,
    required super.child,
    super.key,
  });

  final ValueChanged<AdminSection> irA;

  /// Regresa a la sección desde la que se llegó (p. ej. tras la campana).
  final VoidCallback volver;
  final bool puedeVolver;
  final ValueListenable<int> noLeidas;

  /// Sección visible; las pantallas conservadas vivas lo usan para refrescarse
  /// al volver a ser la activa.
  final ValueListenable<AdminSection> actual;

  static AdminShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminShellScope>();

  @override
  bool updateShouldNotify(AdminShellScope old) =>
      puedeVolver != old.puedeVolver ||
      noLeidas != old.noLeidas ||
      actual != old.actual;
}
