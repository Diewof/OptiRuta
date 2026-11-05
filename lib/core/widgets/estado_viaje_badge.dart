import 'package:flutter/material.dart';

import '../../features/viajes/domain/entities/estado_viaje.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'marca_icon.dart';

/// Badge del ciclo de vida del viaje. Usa neutros y el azul de acción, no los
/// colores del semáforo, para no confundir «En curso» con «Rentable».
class EstadoViajeBadge extends StatelessWidget {
  const EstadoViajeBadge({
    required this.estado,
    this.compacto = false,
    super.key,
  });

  final EstadoViaje estado;
  final bool compacto;

  ({Color fondo, Color texto, MarcaIconos icono, bool borde}) get _estilo =>
      switch (estado) {
        EstadoViaje.planificado => (
          fondo: AppColors.card,
          texto: AppColors.textPrimary,
          icono: MarcaIconos.calendario,
          borde: true,
        ),
        EstadoViaje.asignado => (
          fondo: AppColors.navyTint,
          texto: AppColors.textPrimary,
          icono: MarcaIconos.asignado,
          borde: false,
        ),
        EstadoViaje.enCurso => (
          fondo: AppColors.primary,
          texto: AppColors.onPrimary,
          icono: MarcaIconos.ruta,
          borde: false,
        ),
        EstadoViaje.finalizado => (
          fondo: AppColors.navyTint12,
          texto: AppColors.textPrimary,
          icono: MarcaIconos.check,
          borde: false,
        ),
        EstadoViaje.cerrado => (
          fondo: AppColors.slate,
          texto: AppColors.onPrimary,
          icono: MarcaIconos.lock,
          borde: false,
        ),
        EstadoViaje.cancelado => (
          fondo: AppColors.errorTint,
          texto: AppColors.textPrimary,
          icono: MarcaIconos.alerta,
          borde: false,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final e = _estilo;
    return Semantics(
      label: 'Estado del viaje: ${estado.etiqueta}',
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: compacto ? 20 : 24),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: e.fondo,
            borderRadius: AppRadius.pillAll,
            border: e.borde
                ? Border.all(color: AppColors.borderInput, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MarcaIcon(e.icono, size: 14, color: e.texto),
              const SizedBox(width: AppSpacing.x1),
              Text(
                estado.etiqueta,
                style: AppTypography.label.copyWith(
                  fontSize: compacto ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: e.texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
