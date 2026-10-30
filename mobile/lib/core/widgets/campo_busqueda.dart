import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_spacing.dart';

/// Campo de búsqueda de las listas del Administrador: label siempre visible
/// y filtrado en vivo a través de [alCambiar].
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({
    required this.etiqueta,
    required this.alCambiar,
    super.key,
  });

  final String etiqueta;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      child: TextField(
        onChanged: alCambiar,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: const Icon(LucideIcons.search),
        ),
      ),
    );
  }
}
