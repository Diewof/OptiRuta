import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/dato_marca.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../domain/entities/categoria_costo.dart';
import '../../domain/entities/costo_viaje.dart';

/// Costos del viaje que el conductor ve y confirma: ACPM y costos manuales
/// (valor estimado → real) y peajes de solo lectura (llegan por GoPass). No
/// incluye comisión ni mantenimiento amortizado: no son datos del conductor.
///
/// Al confirmar el real, el «≈ estimado» sale y entra el real con su check.
class CostosViajeCard extends StatelessWidget {
  const CostosViajeCard({
    required this.costos,
    required this.alEditar,
    this.deshabilitado = false,
    super.key,
  });

  final List<CostoViaje> costos;
  final bool deshabilitado;

  /// Abre la hoja para confirmar el valor real de [costo].
  final void Function(CostoViaje costo) alEditar;

  static MarcaIconos _iconoDe(CategoriaCosto c) => switch (c) {
    CategoriaCosto.acpm => MarcaIconos.acpm,
    CategoriaCosto.peaje => MarcaIconos.peaje,
    CategoriaCosto.cargue => MarcaIconos.hitoCargue,
    CategoriaCosto.descargue => MarcaIconos.hitoDestino,
    CategoriaCosto.parqueadero => MarcaIconos.dobleTroque,
    CategoriaCosto.aceite ||
    CategoriaCosto.lavado ||
    CategoriaCosto.engrase => MarcaIconos.mantenimiento,
    _ => MarcaIconos.documento,
  };

  @override
  Widget build(BuildContext context) {
    final List<CostoViaje> visibles = costos
        .where(
          (CostoViaje c) =>
              c.categoria != CategoriaCosto.comision &&
              c.categoria != CategoriaCosto.mantenimientoAmortizado,
        )
        .toList();
    final List<CostoViaje> peajes = visibles
        .where((CostoViaje c) => c.categoria == CategoriaCosto.peaje)
        .toList();
    final List<CostoViaje> editables = visibles
        .where((CostoViaje c) => c.categoria != CategoriaCosto.peaje)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Costos del viaje', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x2),
          if (editables.isEmpty && peajes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
              child: Text(
                'Todavía no hay costos para este viaje.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          for (int i = 0; i < editables.length; i++)
            _FilaCosto(
              costo: editables[i],
              icono: _iconoDe(editables[i].categoria),
              conSeparador: i < editables.length - 1 || peajes.isNotEmpty,
              onEditar: deshabilitado ? null : () => alEditar(editables[i]),
            ),
          if (peajes.isNotEmpty) _FilaPeajes(peajes: peajes),
        ],
      ),
    );
  }
}

class _FilaCosto extends StatelessWidget {
  const _FilaCosto({
    required this.costo,
    required this.icono,
    required this.conSeparador,
    required this.onEditar,
  });

  final CostoViaje costo;
  final MarcaIconos icono;
  final bool conSeparador;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    final NumberFormatCop moneda = NumberFormatCop();
    final bool tieneReal = costo.valorReal != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        border: conSeparador
            ? const Border(bottom: BorderSide(color: AppColors.dividerTable))
            : null,
      ),
      child: Row(
        children: <Widget>[
          _FichaIcono(icono),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  costo.categoria.etiqueta,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: AppMotion.efectiva(context, AppMotion.base),
                  switchInCurve: AppMotion.easeOut,
                  transitionBuilder: (Widget child, Animation<double> a) =>
                      FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(a),
                          child: child,
                        ),
                      ),
                  layoutBuilder: (Widget? actual, List<Widget> anteriores) =>
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[...anteriores, ?actual],
                      ),
                  child: tieneReal
                      ? DatoMarca.real(
                          moneda.formatear(costo.valorReal!),
                          key: ValueKey<String>('real-${costo.valorReal}'),
                        )
                      : DatoMarca.estimado(
                          moneda.formatear(costo.valorEstimado),
                          key: const ValueKey<String>('estimado'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: onEditar,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: onEditar == null
                      ? AppColors.borderInput
                      : AppColors.primary,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(tieneReal ? 'Editar' : 'Agregar real'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPeajes extends StatelessWidget {
  const _FilaPeajes({required this.peajes});

  final List<CostoViaje> peajes;

  @override
  Widget build(BuildContext context) {
    final NumberFormatCop moneda = NumberFormatCop();
    final double total = peajes.fold<double>(
      0,
      (double a, CostoViaje c) => a + (c.valorReal ?? c.valorEstimado),
    );
    final bool todosReales = peajes.every(
      (CostoViaje c) => c.valorReal != null,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        children: <Widget>[
          const _FichaIcono(MarcaIconos.peaje),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Peajes',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (todosReales)
                  DatoMarca.real(moneda.formatear(total))
                else
                  DatoMarca.estimado(moneda.formatear(total)),
                const SizedBox(height: 2),
                const Text(
                  'Llegan solos desde GoPass. No tienes que anotarlos.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: 2,
            ),
            decoration: const BoxDecoration(
              color: AppColors.navyTint,
              borderRadius: AppRadius.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const MarcaIcon(
                  MarcaIconos.syncOk,
                  size: 14,
                  color: AppColors.navy,
                ),
                const SizedBox(width: AppSpacing.x1),
                Text(
                  'Automático',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FichaIcono extends StatelessWidget {
  const _FichaIcono(this.icono);

  final MarcaIconos icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.navyTint,
        borderRadius: AppRadius.mdAll,
      ),
      alignment: Alignment.center,
      child: MarcaIcon(icono, size: 22, color: AppColors.navy),
    );
  }
}
