import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_alert.dart';
import 'ilustracion_estado.dart';
import 'secondary_button.dart';

/// Estado de error reutilizable para listados y formularios: mensaje vía
/// [AppAlert] más un botón opcional de reintentar.
///
/// Cuando [destacado] es `true` (listados/pantallas completas, no errores
/// de campo de formulario) antecede al mensaje una ilustración de línea
/// propia -imagen funcional, no decorativa, ver CLAUDE.md "Identidad
/// visual"-.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.mensaje,
    this.onReintentar,
    this.destacado = false,
    super.key,
  });

  final String mensaje;
  final VoidCallback? onReintentar;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (destacado) ...<Widget>[
          const Center(
            child: IlustracionEstadoView(
              IlustracionEstado.rutaInterrumpida,
              ancho: 176,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        AppAlert(mensaje: mensaje),
        if (onReintentar != null) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          SecondaryButton(label: 'Reintentar', onPressed: onReintentar),
        ],
      ],
    );
  }
}
