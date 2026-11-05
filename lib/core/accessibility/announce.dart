import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Envía un anuncio a los servicios de accesibilidad de la plataforma, si el
/// dispositivo los soporta. Úsese solo para cambios de estado que el sistema
/// no anuncia de forma implícita (p. ej. resultado de una acción).
void announceForAccessibility(BuildContext context, String message) {
  if (!MediaQuery.supportsAnnounceOf(context)) return;
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}
