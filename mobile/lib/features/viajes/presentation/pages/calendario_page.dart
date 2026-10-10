import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'viaje_detalle_page.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/usecases/listar_viajes_por_rango_use_case.dart';
import '../bloc/calendario_cubit.dart';
import '../bloc/calendario_state.dart';
import '../widgets/viaje_resumen_card.dart';
import 'agendar_viaje_page.dart';

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

const List<String> _diasSemanaEs = <String>['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Calendario mensual de viajes del Administrador: grid navegable con puntos
/// de estado por día y lista de viajes del día seleccionado.
class CalendarioPage extends StatelessWidget {
  const CalendarioPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CalendarioCubit>(
      create: (BuildContext context) => CalendarioCubit(
        listarPorRango: ListarViajesPorRangoUseCase(
          context.read<ViajeRepository>(),
        ),
      ),
      child: _CalendarioView(usuario: usuario),
    );
  }
}

class _CalendarioView extends StatelessWidget {
  const _CalendarioView({required this.usuario});

  final Usuario usuario;

  Future<void> _agendarViaje(BuildContext context) async {
    final bool? creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AgendarViajePage()),
    );
    if (creado == true && context.mounted) {
      context.read<CalendarioCubit>().recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Viajes',
      seccionActual: AdminSection.calendario,
      usuario: usuario,
      body: BlocBuilder<CalendarioCubit, CalendarioState>(
        builder: (BuildContext context, CalendarioState state) {
          return switch (state) {
            CalendarioCargando() => const LoadingState(),
            CalendarioError(:final mensaje) => Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: AppAlert(mensaje: mensaje),
            ),
            CalendarioListo() => _Contenido(
              estado: state,
              onAgendar: () => _agendarViaje(context),
            ),
          };
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado, required this.onAgendar});

  final CalendarioListo estado;
  final VoidCallback onAgendar;

  @override
  Widget build(BuildContext context) {
    final List<ViajeResumen> viajesDelDia = estado.viajesDelDia;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            children: <Widget>[
              _GridMes(estado: estado),
              const SizedBox(height: AppSpacing.x4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _tituloDia(estado.diaSeleccionado),
                      style: AppTypography.subtitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    '${viajesDelDia.length} viaje${viajesDelDia.length == 1 ? '' : 's'}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              if (viajesDelDia.isEmpty)
                const EmptyState(
                  icono: LucideIcons.truck,
                  mensaje: 'No hay viajes programados para este día.',
                )
              else
                for (final ViajeResumen v in viajesDelDia) ...<Widget>[
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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: PrimaryActionButton(
            label: 'Agendar viaje',
            leadingIcon: LucideIcons.plus,
            onPressed: onAgendar,
          ),
        ),
      ],
    );
  }

  static String _tituloDia(DateTime dia) {
    const List<String> dias = <String>[
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return '${dias[dia.weekday - 1]} ${dia.day} de ${_mesesEs[dia.month - 1]}';
  }
}

class _GridMes extends StatelessWidget {
  const _GridMes({required this.estado});

  final CalendarioListo estado;

  @override
  Widget build(BuildContext context) {
    final DateTime mes = estado.mesMostrado;
    final int diasEnMes = DateTime(mes.year, mes.month + 1, 0).day;
    final int primerDiaSemana = DateTime(mes.year, mes.month).weekday; // 1=lun
    final int celdasIniciales = primerDiaSemana - 1;
    final int totalCeldas = ((celdasIniciales + diasEnMes) / 7).ceil() * 7;

    final Map<int, List<EstadoViaje>> estadosPorDia =
        <int, List<EstadoViaje>>{};
    for (final ViajeResumen v in estado.viajesDelMes) {
      final DateTime? f = v.fechaSalidaProgramada;
      if (f == null || f.year != mes.year || f.month != mes.month) continue;
      estadosPorDia.putIfAbsent(f.day, () => <EstadoViaje>[]).add(v.estado);
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                onPressed: () =>
                    context.read<CalendarioCubit>().irAMesAnterior(),
                icon: const Icon(LucideIcons.chevronLeft),
                tooltip: 'Mes anterior',
              ),
              Expanded(
                child: Text(
                  '${_mesesEs[mes.month - 1]} ${mes.year}',
                  style: AppTypography.subtitle,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () =>
                    context.read<CalendarioCubit>().irAMesSiguiente(),
                icon: const Icon(LucideIcons.chevronRight),
                tooltip: 'Mes siguiente',
              ),
            ],
          ),
          Row(
            children: <Widget>[
              for (final String d in _diasSemanaEs)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCeldas,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (BuildContext context, int i) {
              final int numeroDia = i - celdasIniciales + 1;
              final bool esDelMes = numeroDia >= 1 && numeroDia <= diasEnMes;
              if (!esDelMes) return const SizedBox.shrink();

              final DateTime fecha = DateTime(mes.year, mes.month, numeroDia);
              final bool seleccionado =
                  fecha.year == estado.diaSeleccionado.year &&
                  fecha.month == estado.diaSeleccionado.month &&
                  fecha.day == estado.diaSeleccionado.day;
              final List<EstadoViaje>? estados = estadosPorDia[numeroDia];
              final Color? colorPunto = estados == null
                  ? null
                  : estados.every(
                      (EstadoViaje e) =>
                          e == EstadoViaje.finalizado ||
                          e == EstadoViaje.cerrado,
                    )
                  ? AppColors.success
                  : AppColors.navy;

              return InkWell(
                onTap: () =>
                    context.read<CalendarioCubit>().seleccionarDia(fecha),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: seleccionado ? AppColors.navy : null,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$numeroDia',
                        style: AppTypography.body.copyWith(
                          color: seleccionado
                              ? AppColors.onNavy
                              : AppColors.textPrimary,
                          fontWeight: seleccionado
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 5,
                      height: 5,
                      child: colorPunto == null
                          ? null
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorPunto,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: <Widget>[
              _Leyenda(color: AppColors.navy, etiqueta: 'Programado'),
              const SizedBox(width: AppSpacing.x4),
              _Leyenda(color: AppColors.success, etiqueta: 'Completado'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.etiqueta});

  final Color color;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.x1),
        Text(
          etiqueta,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
