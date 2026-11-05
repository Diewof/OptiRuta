import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/conductor_scaffold.dart';
import '../../../../core/widgets/conductor_section.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/repositories/rentabilidad_repository.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/usecases/listar_historial_viajes_use_case.dart';
import '../../domain/usecases/rentabilidad_marginal_use_case.dart';
import '../bloc/historial_cubit.dart';
import '../bloc/historial_state.dart';
import '../widgets/viaje_resumen_card.dart';

/// Historial de viajes del Conductor (vista 06 del diseño): solo los viajes
/// propios (RLS `viaje_select_conductor_propio` ya filtra), con filtro de
/// estado y rentabilidad marginal por viaje cerrado. Reutiliza [HistorialCubit]
/// tal cual la usa Seguimiento del Administrador: la consulta ya está
/// acotada por fila via RLS, no hace falta un cubit distinto por rol.
class ConductorHistorialPage extends StatefulWidget {
  const ConductorHistorialPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  State<ConductorHistorialPage> createState() => _ConductorHistorialPageState();
}

class _ConductorHistorialPageState extends State<ConductorHistorialPage> {
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
    return BlocProvider<HistorialCubit>(
      create: (BuildContext context) => HistorialCubit(
        listar: ListarHistorialViajesUseCase(context.read<ViajeRepository>()),
        rentabilidadMarginal: RentabilidadMarginalUseCase(
          context.read<RentabilidadRepository>(),
        ),
      ),
      child: ConductorScaffold(
        titulo: 'Historial de viajes',
        seccionActual: ConductorSection.historial,
        usuario: widget.usuario,
        body: BlocBuilder<HistorialCubit, HistorialState>(
          builder: (BuildContext context, HistorialState state) {
            return switch (state) {
              HistorialCargando() => const LoadingState(),
              HistorialError(:final mensaje) => Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: AppAlert(mensaje: mensaje),
              ),
              HistorialListo(:final viajes) when viajes.isEmpty =>
                const EmptyState(
                  icono: LucideIcons.history,
                  titulo: 'Sin historial',
                  mensaje: 'Todavía no tienes viajes registrados.',
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
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.x4,
                            ),
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
        ),
      ),
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
        height: 48,
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
