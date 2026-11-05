import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/viaje_resumen.dart';

/// Navegación entre viajes activos: flecha anterior, menú desplegable con
/// todos y flecha siguiente. Las flechas se desactivan en los extremos. Con
/// [mostrarConductor] cada viaje se identifica también por su conductor
/// (Resumen del administrador).
class SelectorViajeActivo extends StatelessWidget {
  const SelectorViajeActivo({
    required this.viajes,
    required this.seleccionadoId,
    required this.alSeleccionar,
    this.deshabilitado = false,
    this.mostrarConductor = false,
    super.key,
  });

  final List<ViajeResumen> viajes;
  final String seleccionadoId;
  final ValueChanged<String> alSeleccionar;
  final bool deshabilitado;
  final bool mostrarConductor;

  @override
  Widget build(BuildContext context) {
    final int indice = viajes.indexWhere(
      (ViajeResumen v) => v.id == seleccionadoId,
    );
    final bool hayAnterior = !deshabilitado && indice > 0;
    final bool haySiguiente = !deshabilitado && indice < viajes.length - 1;

    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Viaje anterior',
          onPressed: hayAnterior
              ? () => alSeleccionar(viajes[indice - 1].id)
              : null,
          icon: const Icon(LucideIcons.chevronLeft),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.borderInput),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
              child: DropdownButton<String>(
                value: seleccionadoId,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                icon: const Icon(LucideIcons.chevronDown, size: 18),
                onChanged: deshabilitado
                    ? null
                    : (String? id) {
                        if (id != null) alSeleccionar(id);
                      },
                selectedItemBuilder: (BuildContext context) => <Widget>[
                  for (int i = 0; i < viajes.length; i++)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Viaje ${i + 1} de ${viajes.length} · '
                        '${mostrarConductor ? viajes[i].nombreConductor : viajes[i].remision}',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                items: <DropdownMenuItem<String>>[
                  for (final ViajeResumen v in viajes)
                    DropdownMenuItem<String>(
                      value: v.id,
                      child: Text(
                        mostrarConductor
                            ? '${v.nombreConductor} · ${v.origen} → ${v.destino}'
                            : '${v.remision} · ${v.origen} → ${v.destino}',
                        style: AppTypography.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Viaje siguiente',
          onPressed: haySiguiente
              ? () => alSeleccionar(viajes[indice + 1].id)
              : null,
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
    );
  }
}
