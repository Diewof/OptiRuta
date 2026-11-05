import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'admin_section.dart';
import 'admin_shell_scope.dart';

/// Ejecuta [alActivar] cada vez que [seccion] pasa a ser la visible del shell.
/// El shell mantiene las pantallas vivas, así que sin esto mostrarían datos
/// de la última vez que se abrieron. Fuera del shell no hace nada.
class AlActivarSeccion extends StatefulWidget {
  const AlActivarSeccion({
    required this.seccion,
    required this.alActivar,
    required this.child,
    super.key,
  });

  final AdminSection seccion;
  final VoidCallback alActivar;
  final Widget child;

  @override
  State<AlActivarSeccion> createState() => _AlActivarSeccionState();
}

class _AlActivarSeccionState extends State<AlActivarSeccion> {
  ValueListenable<AdminSection>? _actual;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueListenable<AdminSection>? nueva = AdminShellScope.maybeOf(
      context,
    )?.actual;
    if (identical(nueva, _actual)) return;
    _actual?.removeListener(_alCambiar);
    _actual = nueva;
    nueva?.addListener(_alCambiar);
  }

  void _alCambiar() {
    if (_actual?.value == widget.seccion) widget.alActivar();
  }

  @override
  void dispose() {
    _actual?.removeListener(_alCambiar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
