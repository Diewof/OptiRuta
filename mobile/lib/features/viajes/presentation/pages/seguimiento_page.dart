import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'viaje_detalle_page.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/estado_viaje_badge.dart';
import '../../../../core/widgets/retraso_badge.dart';
import '../../../../core/widgets/vehiculo_thumb.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/repositories/hito_repository.dart';
import '../../domain/repositories/rentabilidad_repository.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/listar_historial_viajes_use_case.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import '../../domain/usecases/rentabilidad_marginal_use_case.dart';
import '../bloc/historial_cubit.dart';
import '../bloc/historial_state.dart';
import '../bloc/seguimiento_en_curso_cubit.dart';
import '../bloc/seguimiento_en_curso_state.dart';
import '../widgets/milestone_stepper.dart';
import '../widgets/viaje_resumen_card.dart';

/// Seguimiento: viajes en curso (con stepper de hitos) e historial paginado
/// con rentabilidad marginal. Dos pestañas sobre la misma pantalla, como en
/// el diseño (Seguimiento.dc.html / Historial.dc.html comparten cabecera).
class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  State<SeguimientoPage> createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<SeguimientoEnCursoCubit>(
          create: (BuildContext context) => SeguimientoEnCursoCubit(
            listarActivos: ListarViajesActivosUseCase(
              context.read<ViajeRepository>(),
            ),
            listarHitos: ListarHitosUseCase(context.read<HitoRepository>()),
          ),
        ),
        BlocProvider<HistorialCubit>(
          create: (BuildContext context) => HistorialCubit(
            listar: ListarHistorialViajesUseCase(
              context.read<ViajeRepository>(),
            ),
            rentabilidadMarginal: RentabilidadMarginalUseCase(
              context.read<RentabilidadRepository>(),
            ),
          ),
        ),
      ],
      child: AdminScaffold(
        titulo: 'Viajes',
        seccionActual: AdminSection.seguimiento,
        usuario: widget.usuario,
        body: Column(
          children: <Widget>[
            _TabHeader(controller: _tabs),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const <Widget>[_EnCursoTab(), _HistorialTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.borderCard)),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          return Row(
            children: <Widget>[
              Expanded(
                child: _TabButton(
                  label: 'En curso',
                  activo: controller.index == 0,
                  onTap: () => controller.animateTo(0),
                ),
              ),
              Expanded(
                child: _TabButton(
                  label: 'Historial',
                  activo: controller.index == 1,
                  onTap: () => controller.animateTo(1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: activo ? AppColors.brandRed : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
            color: activo ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EnCursoTab extends StatelessWidget {
  const _EnCursoTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SeguimientoEnCursoCubit, SeguimientoEnCursoState>(
      builder: (BuildContext context, SeguimientoEnCursoState state) {
        return switch (state) {
          SeguimientoEnCursoCargando() => const LoadingState(),
          SeguimientoEnCursoError(:final mensaje) => Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: AppAlert(mensaje: mensaje),
          ),
          SeguimientoEnCursoListo(:final viajes) when viajes.isEmpty =>
            const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: EmptyState(
                icono: LucideIcons.truck,
                titulo: 'Sin viajes en curso',
                mensaje: 'No hay viajes ASIGNADO o EN_CURSO en este momento.',
              ),
            ),
          SeguimientoEnCursoListo(:final viajes) => RefreshIndicator(
            onRefresh: () => context.read<SeguimientoEnCursoCubit>().cargar(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.x4),
              itemCount: viajes.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x3),
              itemBuilder: (BuildContext context, int i) {
                final ViajeActivo va = viajes[i];
                return InkWell(
                  borderRadius: AppRadius.lgAll,
                  onTap: () {
                    final SeguimientoEnCursoCubit cubit = context
                        .read<SeguimientoEnCursoCubit>();
                    Navigator.of(context)
                        .push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => ViajeDetallePage(
                              viaje: va.viaje,
                              puedeCerrar: true,
                            ),
                          ),
                        )
                        .then((_) => cubit.cargar());
                  },
                  child: AppCard(
                    stripe: AppCardStripe.left,
                    stripeColor: va.retraso
                        ? AppColors.warning
                        : AppColors.navyTint12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (va.viaje.tipoVehiculo != null) ...<Widget>[
                              VehiculoThumb(
                                tipo: va.viaje.tipoVehiculo!,
                                ancho: 64,
                              ),
                              const SizedBox(width: AppSpacing.x3),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${va.viaje.origen} → ${va.viaje.destino}',
                                    style: AppTypography.subtitle,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    va.viaje.nombreCliente,
                                    style: AppTypography.caption,
                                  ),
                                  const SizedBox(height: AppSpacing.x2),
                                  Wrap(
                                    spacing: AppSpacing.x2,
                                    runSpacing: AppSpacing.x1,
                                    children: <Widget>[
                                      EstadoViajeBadge(
                                        estado: va.viaje.estado,
                                        compacto: true,
                                      ),
                                      if (va.retraso) const RetrasoBadge(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x4),
                        MilestoneStepper(hitos: va.hitos),
                        const SizedBox(height: AppSpacing.x3),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.x3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _Dato(
                                etiqueta: 'Vehículo',
                                valor: va.viaje.placaVehiculo,
                              ),
                            ),
                            Expanded(
                              child: _Dato(
                                etiqueta: 'Conductor',
                                valor: va.viaje.nombreConductor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        };
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          etiqueta,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          valor,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HistorialTab extends StatefulWidget {
  const _HistorialTab();

  @override
  State<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends State<_HistorialTab> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
  }

  void _alDesplazar() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      context.read<HistorialCubit>().cargarSiguientePagina();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_alDesplazar);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistorialCubit, HistorialState>(
      builder: (BuildContext context, HistorialState state) {
        return switch (state) {
          HistorialCargando() => const LoadingState(),
          HistorialError(:final mensaje) => Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: AppAlert(mensaje: mensaje),
          ),
          HistorialListo(:final viajes) when viajes.isEmpty => const Padding(
            padding: EdgeInsets.all(AppSpacing.x4),
            child: EmptyState(
              icono: LucideIcons.history,
              titulo: 'Sin historial',
              mensaje: 'Todavía no hay viajes registrados.',
            ),
          ),
          HistorialListo() => Column(
            children: <Widget>[
              _FiltrosEstado(estado: state),
              Expanded(
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  itemCount: state.viajes.length + (state.hayMas ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.x2),
                  itemBuilder: (BuildContext context, int i) {
                    if (i >= state.viajes.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _HistorialRow(item: state.viajes[i]);
                  },
                ),
              ),
            ],
          ),
        };
      },
    );
  }
}

class _FiltrosEstado extends StatelessWidget {
  const _FiltrosEstado({required this.estado});

  final HistorialListo estado;

  @override
  Widget build(BuildContext context) {
    final Map<String, EstadoViaje?> opciones = <String, EstadoViaje?>{
      'Todos': null,
      'Finalizados': EstadoViaje.finalizado,
      'Cerrados': EstadoViaje.cerrado,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        0,
      ),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            for (final MapEntry<String, EstadoViaje?> op in opciones.entries)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.x2),
                child: _Chip(
                  label: op.key,
                  activo: estado.filtroEstado == op.value,
                  onTap: () => context
                      .read<HistorialCubit>()
                      .cargarPrimeraPagina(filtroEstado: op.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.activo, required this.onTap});

  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillAll,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
        decoration: BoxDecoration(
          color: activo ? AppColors.navyTint : AppColors.card,
          border: Border.all(
            color: activo ? AppColors.primary : AppColors.borderInput,
            width: 1.5,
          ),
          borderRadius: AppRadius.pillAll,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textPrimary,
            fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _HistorialRow extends StatelessWidget {
  const _HistorialRow({required this.item});

  final ViajeConRentabilidad item;

  @override
  Widget build(BuildContext context) {
    return ViajeResumenCard(
      viaje: item.viaje,
      onTap: () {
        final HistorialCubit cubit = context.read<HistorialCubit>();
        Navigator.of(context)
            .push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ViajeDetallePage(viaje: item.viaje, puedeCerrar: true),
              ),
            )
            .then((_) => cubit.recargar());
      },
      pie: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Rentabilidad',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            item.rentabilidad == null
                ? '—'
                : r'$'
                      '${item.rentabilidad!.toStringAsFixed(0)}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
