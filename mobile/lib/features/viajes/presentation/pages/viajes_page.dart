import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/al_activar_seccion.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/chip_opcion.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import '../../domain/usecases/listar_viajes_por_rango_use_case.dart';
import '../bloc/viajes_cubit.dart';
import '../widgets/viaje_resumen_card.dart';
import 'agendar_viaje_page.dart';
import 'viaje_detalle_page.dart';

const List<String> _diasCortos = <String>[
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];
const List<String> _mesesCortos = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Lista única de viajes del Administrador: vistas rápidas (Hoy, Programados,
/// En curso, Finalizados), búsqueda y un modo Agenda que agrupa por día.
class ViajesPage extends StatelessWidget {
  const ViajesPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ViajesCubit>(
      create: (BuildContext context) {
        final ViajeRepository repo = context.read<ViajeRepository>();
        return ViajesCubit(
          listarPorRango: ListarViajesPorRangoUseCase(repo),
          listarActivos: ListarViajesActivosUseCase(repo),
        );
      },
      child: _ViajesView(usuario: usuario),
    );
  }
}

class _ViajesView extends StatelessWidget {
  const _ViajesView({required this.usuario});

  final Usuario usuario;

  Future<void> _agendar(BuildContext context) async {
    final ViajesCubit cubit = context.read<ViajesCubit>();
    final bool? creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AgendarViajePage()),
    );
    if (creado == true) cubit.cargar(silencioso: true);
  }

  @override
  Widget build(BuildContext context) {
    return AlActivarSeccion(
      seccion: AdminSection.viajes,
      alActivar: () => context.read<ViajesCubit>().cargar(silencioso: true),
      child: AdminScaffold(
        titulo: 'Viajes',
        seccionActual: AdminSection.viajes,
        usuario: usuario,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _agendar(context),
          icon: const Icon(LucideIcons.plus),
          label: const Text('Agendar viaje'),
        ),
        body: BlocBuilder<ViajesCubit, ViajesState>(
          builder: (BuildContext context, ViajesState state) {
            return switch (state) {
              ViajesCargando() => const LoadingState(),
              ViajesError(:final mensaje) => Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: AppAlert(mensaje: mensaje),
              ),
              ViajesListo() => _Contenido(estado: state),
            };
          },
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado});

  final ViajesListo estado;

  @override
  Widget build(BuildContext context) {
    final List<ViajeResumen> visibles = estado.visibles;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  onChanged: context.read<ViajesCubit>().buscar,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Buscar viaje',
                    hintText: 'Cliente, placa, conductor, ruta o remisión',
                    prefixIcon: Icon(LucideIcons.search),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              IconButton.outlined(
                tooltip: estado.agenda ? 'Ver como lista' : 'Ver como agenda',
                onPressed: context.read<ViajesCubit>().alternarAgenda,
                icon: Icon(
                  estado.agenda ? LucideIcons.list : LucideIcons.calendarDays,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Row(
            children: <Widget>[
              for (final FiltroViajes f in FiltroViajes.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.x2),
                  child: ChipOpcion(
                    etiqueta: f == FiltroViajes.todos
                        ? f.etiqueta
                        : '${f.etiqueta} · ${estado.cuantos(f)}',
                    seleccionado: f == estado.filtro,
                    onTap: () => context.read<ViajesCubit>().elegirFiltro(f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                context.read<ViajesCubit>().cargar(silencioso: true),
            child: visibles.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    children: <Widget>[
                      EmptyState(
                        icono: LucideIcons.truck,
                        mensaje: estado.busqueda.trim().isNotEmpty
                            ? 'Ningún viaje coincide con la búsqueda.'
                            : 'No hay viajes en esta vista.',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x4,
                      AppSpacing.x3,
                      AppSpacing.x4,
                      88, // deja libre el botón flotante
                    ),
                    children: <Widget>[
                      ..._filas(context, visibles, estado.agenda, estado.hoy),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  List<Widget> _filas(
    BuildContext context,
    List<ViajeResumen> viajes,
    bool agenda,
    DateTime hoy,
  ) {
    final List<Widget> filas = <Widget>[];
    String? ultimoDia;
    for (final ViajeResumen v in viajes) {
      if (agenda) {
        final String dia = etiquetaDia(v.fechaSalidaProgramada, hoy);
        if (dia != ultimoDia) {
          filas.add(
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.x2,
                bottom: AppSpacing.x2,
              ),
              child: Text(
                dia,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
          ultimoDia = dia;
        }
      }
      filas.add(
        ViajeResumenCard(
          viaje: v,
          onTap: () {
            final ViajesCubit cubit = context.read<ViajesCubit>();
            Navigator.of(context)
                .push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ViajeDetallePage(viaje: v, puedeCerrar: true),
                  ),
                )
                .then((_) => cubit.cargar(silencioso: true));
          },
        ),
      );
      filas.add(const SizedBox(height: AppSpacing.x2));
    }
    return filas;
  }
}

/// «Hoy», «Mañana», «Ayer» o `Lun 3 nov`; `Sin fecha` si no hay salida.
String etiquetaDia(DateTime? fecha, DateTime hoy) {
  if (fecha == null) return 'Sin fecha';
  final DateTime dia = DateTime(fecha.year, fecha.month, fecha.day);
  final int diferencia = dia
      .difference(DateTime(hoy.year, hoy.month, hoy.day))
      .inDays;
  return switch (diferencia) {
    0 => 'Hoy',
    1 => 'Mañana',
    -1 => 'Ayer',
    _ =>
      '${_diasCortos[dia.weekday - 1]} ${dia.day} ${_mesesCortos[dia.month - 1]}',
  };
}
