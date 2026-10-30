import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/chip_opcion.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/selector_mes.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/rendimiento_combustible.dart';
import '../../domain/repositories/combustible_repository.dart';
import '../../domain/usecases/combustible_use_cases.dart';
import '../bloc/combustible_cubit.dart';
import '../bloc/combustible_state.dart';

/// Control de combustible (pestaña del Resumen): km por galón real de cada
/// vehículo y ruta contra los 3 meses anteriores. Una caída sostenida se
/// marca como «consumo anómalo»: el GPS no distingue ralentí, extracción o
/// falla mecánica, así que la app no afirma la causa.
class CombustiblePage extends StatelessWidget {
  const CombustiblePage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CombustibleCubit>(
      create: (BuildContext context) => CombustibleCubit(
        obtener: ObtenerRendimientoCombustibleUseCase(
          context.read<CombustibleRepository>(),
        ),
      ),
      child: _CombustibleView(usuario: usuario),
    );
  }
}

class _CombustibleView extends StatelessWidget {
  const _CombustibleView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Resumen',
      seccionActual: AdminSection.combustible,
      usuario: usuario,
      body: BlocBuilder<CombustibleCubit, CombustibleState>(
        builder: (BuildContext context, CombustibleState state) {
          return switch (state) {
            CombustibleCargando() => const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: Column(
                children: <Widget>[
                  SkeletonBlock(alto: 48),
                  SizedBox(height: AppSpacing.x3),
                  SkeletonBlock(alto: 140, radio: 16),
                  SizedBox(height: AppSpacing.x3),
                  SkeletonBlock(alto: 140, radio: 16),
                ],
              ),
            ),
            CombustibleError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () =>
                      context.read<CombustibleCubit>().recargar(),
                ),
              ],
            ),
            CombustibleListo() => _Contenido(estado: state),
          };
        },
      ),
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.estado});

  final CombustibleListo estado;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  DimensionCombustible _dimension = DimensionCombustible.vehiculo;

  @override
  Widget build(BuildContext context) {
    final CombustibleCubit cubit = context.read<CombustibleCubit>();
    final List<RendimientoCombustible> filas =
        widget.estado.porDimension[_dimension] ??
        const <RendimientoCombustible>[];

    return RefreshIndicator(
      onRefresh: cubit.recargar,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          SelectorMes(
            mes: widget.estado.mes,
            onAnterior: cubit.irAMesAnterior,
            onSiguiente: cubit.irAMesSiguiente,
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: <Widget>[
              for (final DimensionCombustible d in DimensionCombustible.values)
                ChipOpcion(
                  etiqueta: d.etiqueta,
                  seleccionado: d == _dimension,
                  onTap: () => setState(() => _dimension = d),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          if (filas.isEmpty)
            const EmptyState(
              icono: LucideIcons.fuel,
              titulo: 'Sin rendimiento medido',
              mensaje:
                  'Se necesitan viajes finalizados con km por GPS y tanqueos '
                  'registrados por el conductor.',
            )
          else
            for (final RendimientoCombustible f in filas) ...<Widget>[
              _TarjetaRendimiento(fila: f),
              const SizedBox(height: AppSpacing.x3),
            ],
          const _Criterios(),
        ],
      ),
    );
  }
}

class _TarjetaRendimiento extends StatelessWidget {
  const _TarjetaRendimiento({required this.fila});

  final RendimientoCombustible fila;

  @override
  Widget build(BuildContext context) {
    final double? variacion = fila.variacionPct;
    final String viajes = fila.viajes == 1
        ? '1 viaje'
        : '${fila.viajes} viajes';

    return AppCard(
      stripe: fila.alerta ? AppCardStripe.left : AppCardStripe.none,
      stripeColor: AppColors.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(fila.clave, style: AppTypography.subtitle),
                    Text(
                      '$viajes · ${formatearDecimal(fila.km, decimales: 0)} km '
                      '· ${formatearDecimal(fila.galones)} gal',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Text(
                '${formatearDecimal(fila.kmPorGalon, decimales: 2)} km/gal',
                style: AppTypography.subtitle.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            <String>[
              if (fila.kmPorGalonPrevio != null)
                'Antes: ${formatearDecimal(fila.kmPorGalonPrevio!, decimales: 2)} km/gal'
              else
                'Sin histórico suficiente',
              if (variacion != null) formatearPorcentaje(variacion),
              if (fila.referenciaKmGalon != null)
                'Referencia: ${formatearDecimal(fila.referenciaKmGalon!)} km/gal',
            ].join(' · '),
            style: AppTypography.caption.copyWith(
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (fila.alerta) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            const StatusBadge(
              label: 'Consumo anómalo · revisar vehículo',
              tone: StatusTone.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _Criterios extends StatelessWidget {
  const _Criterios();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Rendimiento = km medidos por GPS ÷ galones que registra el conductor, '
      'solo en viajes finalizados. Se compara con los 3 meses anteriores y se '
      'alerta con una caída de 15 % o más (mínimo 2 viajes en cada período). '
      'Indica que el consumo subió, no la causa: puede ser ralentí, una '
      'extracción o una falla mecánica.',
      style: AppTypography.caption,
    );
  }
}
