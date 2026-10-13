import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/tipo_notificacion.dart';

/// Icono y color de cada tipo de notificación. Una sola fuente para la bandeja
/// y el Resumen: lo completado va en verde, lo informativo en azul marino, las
/// advertencias en ámbar y lo crítico en rojo de error.
extension TipoNotificacionVisual on TipoNotificacion {
  IconData get icono => switch (this) {
    TipoNotificacion.viajeCompletado => LucideIcons.circleCheck,
    TipoNotificacion.retraso => LucideIcons.clock,
    TipoNotificacion.documentoPorVencer => LucideIcons.fileText,
    TipoNotificacion.documentoVencido => LucideIcons.fileX,
    TipoNotificacion.mantenimientoProximo => LucideIcons.wrench,
    TipoNotificacion.mantenimientoVencido => LucideIcons.wrench,
    TipoNotificacion.checklistFalla => LucideIcons.clipboardX,
    TipoNotificacion.peajeRegistrado => LucideIcons.info,
    TipoNotificacion.novedad => LucideIcons.info,
    TipoNotificacion.paradaProlongada => LucideIcons.circlePause,
    TipoNotificacion.desvioRuta => LucideIcons.route,
    TipoNotificacion.satisfaccionBaja => LucideIcons.messageSquareWarning,
  };

  Color get color => switch (this) {
    TipoNotificacion.viajeCompletado => AppColors.success,
    TipoNotificacion.peajeRegistrado ||
    TipoNotificacion.novedad => AppColors.navy,
    TipoNotificacion.documentoVencido ||
    TipoNotificacion.mantenimientoVencido ||
    TipoNotificacion.checklistFalla => AppColors.error,
    TipoNotificacion.retraso ||
    TipoNotificacion.documentoPorVencer ||
    TipoNotificacion.mantenimientoProximo ||
    TipoNotificacion.paradaProlongada ||
    TipoNotificacion.desvioRuta ||
    TipoNotificacion.satisfaccionBaja => AppColors.warning,
  };
}
