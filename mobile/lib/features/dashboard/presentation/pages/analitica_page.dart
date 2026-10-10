import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/cifra_animada.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/ilustracion_estado.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../../../core/widgets/semaforo_badge.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../viajes/domain/entities/rentabilidad_consolidada.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';
import '../../../viajes/domain/repositories/rentabilidad_repository.dart';
import '../../../viajes/domain/repositories/viaje_repository.dart';
import '../../../viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import '../../../viajes/domain/usecases/rentabilidad_consolidada_use_case.dart';
import '../../../viajes/presentation/pages/viaje_detalle_page.dart';
import '../../../viajes/presentation/widgets/viaje_resumen_card.dart';
import '../bloc/analitica_cubit.dart';
import '../bloc/analitica_state.dart';

const List<String> _mesesEs = <String>[
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Resumen del Administrador (vista inicial): rentabilidad **consolidada** del
/// período con su cifra clave, flota en ruta, viajes en curso y desglose de
/// costos. La rentabilidad **marginal** de cada viaje vive en su propio
/// detalle: nunca se mezclan en la misma cifra.
///
/// Alcance real: ver [AnaliticaCubit]. No hay costo por km ni conteo de
/// costos confirmados por período (sin fuente de datos todavía), y el estado
/// del semáforo lo calculará el servidor cuando se definan los umbrales; aquí
/// solo se usa «Sin datos suficientes» cuando el período no tiene viajes.
class AnaliticaPage extends StatelessWidget {
  const AnaliticaPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AnaliticaCubit>(
      create: (BuildContext context) => AnaliticaCubit(
        rentabilidadConsolidada: RentabilidadConsolidadaUseCase(
          context.read<RentabilidadRepository>(),
        ),
        vehiculoRepository: context.read<VehiculoRepository>(),
        listarViajesActivos: ListarViajesActivosUseCase(
          context.read<ViajeRepository>(),
        ),
      ),
      child: _AnaliticaView(usuario: usuario),
    );
  }
}

class _AnaliticaView extends StatelessWidget {
  const _AnaliticaView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Resumen',
      seccionActual: AdminSection.analitica,
      usuario: usuario,
      body: BlocBuilder<AnaliticaCubit, AnaliticaState>(
        builder: (BuildContext context, AnaliticaState state) {
          return switch (state) {
            AnaliticaCargando() => const _Esqueleto(),
            AnaliticaError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () => context.read<AnaliticaCubit>().recargar(),
                ),
              ],
            ),
            AnaliticaListo() => _Contenido(estado: state),
          };
        },
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: <Widget>[
          SkeletonBlock(alto: 48),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 200, radio: 16),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 120, radio: 16),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 96, radio: 16),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado});

  final AnaliticaListo estado;

  @override
  Widget build(BuildContext context) {
    final RentabilidadConsolidada r = estado.rentabilidad;
    final NumberFormatCop moneda = NumberFormatCop();

    return RefreshIndicator(
      onRefresh: () => context.read<AnaliticaCubit>().recargar(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          _SelectorMes(estado: estado),
          const SizedBox(height: AppSpacing.x3),
          _HeroConsolidada(estado: estado),
          const SizedBox(height: AppSpacing.x3),
          _KpisFlota(estado: estado),
          const SizedBox(height: AppSpacing.x4),
          const Text('Viajes en curso', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x2),
          if (estado.viajesActivos.isEmpty)
            const AppCard(
              child: EmptyState(
                icono: LucideIcons.truck,
                ilustracion: IlustracionEstado.sinViaje,
                titulo: 'Todavía no hay viajes en curso',
                mensaje:
                    'Cuando un conductor salga, verás aquí cómo va el viaje.',
              ),
            )
          else
            for (final ViajeResumen v in estado.viajesActivos) ...<Widget>[
              ViajeResumenCard(
                viaje: v,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ViajeDetallePage(viaje: v, puedeCerrar: true),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
          const SizedBox(height: AppSpacing.x2),
          _DesgloseCostos(rentabilidad: r, moneda: moneda),
        ],
      ),
    );
  }
}

class _SelectorMes extends StatelessWidget {
  const _SelectorMes({required this.estado});

  final AnaliticaListo estado;

  @override
  Widget build(BuildContext context) {
    final DateTime hoy = DateTime.now();
    final bool esMesActual =
        estado.mes.year == hoy.year && estado.mes.month == hoy.month;

    return Row(
      children: <Widget>[
        const Expanded(child: Text('Período', style: AppTypography.subtitle)),
        IconButton(
          onPressed: () => context.read<AnaliticaCubit>().irAMesAnterior(),
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: 'Mes anterior',
          color: AppColors.primary,
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            '${_mesesEs[estado.mes.month - 1]} ${estado.mes.year}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: esMesActual
              ? null
              : () => context.read<AnaliticaCubit>().irAMesSiguiente(),
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: 'Mes siguiente',
          color: AppColors.primary,
        ),
      ],
    );
  }
}

/// Cifra clave: rentabilidad **consolidada** del mes (mantenimiento y sueldo
/// fijo prorrateados incluidos). Solo cuenta viajes cerrados, por eso su base
/// es «Confirmada».
class _HeroConsolidada extends StatelessWidget {
  const _HeroConsolidada({required this.estado});

  final AnaliticaListo estado;

  @override
  Widget build(BuildContext context) {
    final RentabilidadConsolidada r = estado.rentabilidad;
    final bool hayDatos = r.viajesIncluidos > 0;
    final String mes = _mesesEs[estado.mes.month - 1].toLowerCase();
    final TextStyle sobreNavy = AppTypography.caption.copyWith(
      color: AppColors.onNavy.withValues(alpha: 0.75),
    );

    return Semantics(
      container: true,
      label: hayDatos
          ? 'Rentabilidad consolidada de $mes: '
                '${formatearMillones(r.rentabilidadConsolidada)}, '
                'margen ${formatearPorcentaje(r.rentabilidadConsolidada / r.totalFlete * 100)}'
          : 'Rentabilidad consolidada de $mes: sin viajes cerrados',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: const BoxDecoration(
            color: AppColors.navy,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppElevation.float,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x1,
                children: <Widget>[
                  Text(
                    'Rentabilidad consolidada · $mes',
                    style: AppTypography.label.copyWith(
                      color: AppColors.onNavy.withValues(alpha: 0.8),
                    ),
                  ),
                  if (hayDatos)
                    const BaseCalculoChip(
                      base: BaseCalculo.confirmada,
                      sobreOscuro: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x1),
              if (hayDatos) ...<Widget>[
                CifraAnimada(
                  valor: r.rentabilidadConsolidada,
                  formato: formatearMillones,
                  estilo: AppTypography.hero.copyWith(color: AppColors.onNavy),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Margen ${formatearPorcentaje(r.rentabilidadConsolidada / r.totalFlete * 100)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.onNavy,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: AppSpacing.x2),
                const SemaforoBadge(estado: SemaforoRentabilidad.sinDatos),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Todavía no hay viajes cerrados en este período.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.onNavy.withValues(alpha: 0.85),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.x4),
              Container(
                padding: const EdgeInsets.only(top: AppSpacing.x4),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.onNavy.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    _CifraHero(
                      etiqueta: 'Ingresos',
                      valor: formatearMillones(r.totalFlete),
                      estiloEtiqueta: sobreNavy,
                    ),
                    _CifraHero(
                      etiqueta: 'Costos',
                      valor: formatearMillones(r.totalCostos),
                      estiloEtiqueta: sobreNavy,
                    ),
                    _CifraHero(
                      etiqueta: 'Viajes cerrados',
                      valor: '${r.viajesIncluidos}',
                      estiloEtiqueta: sobreNavy,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CifraHero extends StatelessWidget {
  const _CifraHero({
    required this.etiqueta,
    required this.valor,
    required this.estiloEtiqueta,
  });

  final String etiqueta;
  final String valor;
  final TextStyle estiloEtiqueta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(etiqueta, style: estiloEtiqueta),
          const SizedBox(height: 2),
          Text(
            valor,
            style: AppTypography.subtitle.copyWith(
              color: AppColors.onNavy,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpisFlota extends StatelessWidget {
  const _KpisFlota({required this.estado});

  final AnaliticaListo estado;

  @override
  Widget build(BuildContext context) {
    final int total = estado.totalVehiculosActivos;
    final int enRuta = estado.vehiculosEnRuta;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Semantics(
              container: true,
              label: 'Flota en ruta: $enRuta de $total vehículos',
              child: ExcludeSemantics(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const MarcaIcon(
                            MarcaIconos.dobleTroque,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Flexible(
                            child: Text(
                              'Flota en ruta',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '$enRuta',
                              style: AppTypography.display,
                            ),
                            TextSpan(
                              text: ' de $total',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Wrap(
                        spacing: AppSpacing.x1,
                        runSpacing: AppSpacing.x1,
                        children: <Widget>[
                          for (int i = 0; i < total; i++)
                            _Pictograma(enRuta: i < enRuta),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Semantics(
              container: true,
              label: 'Viajes en curso: ${estado.viajesActivos.length}',
              child: ExcludeSemantics(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const MarcaIcon(
                            MarcaIconos.ruta,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Flexible(
                            child: Text(
                              'Viajes en curso',
                              style: AppTypography.label.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        '${estado.viajesActivos.length}',
                        style: AppTypography.display,
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      const Text(
                        'asignados o en ruta',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pictograma extends StatelessWidget {
  const _Pictograma({required this.enRuta});

  final bool enRuta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: enRuta ? AppColors.navy : AppColors.card,
        borderRadius: AppRadius.smAll,
        border: enRuta
            ? null
            : Border.all(color: AppColors.borderInput, width: 1.5),
      ),
      alignment: Alignment.center,
      child: MarcaIcon(
        MarcaIconos.dobleTroque,
        size: 20,
        color: enRuta ? AppColors.onNavy : AppColors.textSecondary,
      ),
    );
  }
}

class _DesgloseCostos extends StatelessWidget {
  const _DesgloseCostos({required this.rentabilidad, required this.moneda});

  final RentabilidadConsolidada rentabilidad;
  final NumberFormatCop moneda;

  @override
  Widget build(BuildContext context) {
    final double total = rentabilidad.totalCostos;
    final List<(String, double, Color)> partes = <(String, double, Color)>[
      (
        'Costos directos (ACPM, peajes, comisión...)',
        rentabilidad.totalCostosDirectos,
        AppColors.navy,
      ),
      (
        'Mantenimiento amortizado',
        rentabilidad.mantenimientoAmortizado,
        AppColors.slate,
      ),
      (
        'Sueldo fijo prorrateado',
        rentabilidad.sueldoFijoProrrateado,
        AppColors.slate,
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Desglose de costos',
                  style: AppTypography.subtitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'Total ${moneda.formatear(total)}',
                style: AppTypography.caption.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            'Incluye mantenimiento y sueldo fijo: solo cuentan en el '
            'consolidado, no en la rentabilidad de cada viaje.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x3),
          for (final (String, double, Color) parte in partes) ...<Widget>[
            _FilaCosto(
              etiqueta: parte.$1,
              valor: parte.$2,
              color: parte.$3,
              porcentaje: total == 0 ? 0 : parte.$2 / total,
              moneda: moneda,
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}

class _FilaCosto extends StatelessWidget {
  const _FilaCosto({
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.porcentaje,
    required this.moneda,
  });

  final String etiqueta;
  final double valor;
  final Color color;
  final double porcentaje;
  final NumberFormatCop moneda;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                etiqueta,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              '${moneda.formatear(valor)} · ${(porcentaje * 100).toStringAsFixed(0)} %',
              style: AppTypography.caption.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: LinearProgressIndicator(
            value: porcentaje.clamp(0, 1),
            minHeight: 8,
            backgroundColor: AppColors.dividerTable,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
