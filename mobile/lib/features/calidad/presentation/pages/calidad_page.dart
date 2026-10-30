import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/chip_opcion.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../../reportes/domain/usecases/cargar_opciones_reporte_use_case.dart';
import '../../../reportes/presentation/widgets/filtros_reporte_card.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/calidad.dart';
import '../../domain/repositories/calidad_repository.dart';
import '../../domain/usecases/calidad_use_cases.dart';
import '../bloc/calidad_cubit.dart';
import '../bloc/calidad_state.dart';
import '../widgets/nivel_calidad_badge.dart';

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

/// Calidad de los viajes (pestaña del Resumen): calificación automática de los
/// viajes cerrados del período por puntualidad, rentabilidad, cliente e
/// incidencias, con ranking y alertas recurrentes. Los costos y la
/// satisfacción viven en las otras pestañas; aquí se cruzan en un solo puntaje.
class CalidadPage extends StatelessWidget {
  const CalidadPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CalidadCubit>(
      create: (BuildContext context) {
        final CalidadRepository repo = context.read<CalidadRepository>();
        return CalidadCubit(
          resumen: ObtenerResumenCalidadUseCase(repo),
          porDimension: ObtenerCalidadPorDimensionUseCase(repo),
          recurrentes: ListarAlertasRecurrentesUseCase(repo),
          cargarOpciones: CargarOpcionesReporteUseCase(
            clientes: context.read<ClienteRepository>(),
            conductores: context.read<ConductorRepository>(),
            vehiculos: context.read<VehiculoRepository>(),
          ).call,
        );
      },
      child: _CalidadView(usuario: usuario),
    );
  }
}

class _CalidadView extends StatelessWidget {
  const _CalidadView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Resumen',
      seccionActual: AdminSection.calidad,
      usuario: usuario,
      body: BlocBuilder<CalidadCubit, CalidadState>(
        builder: (BuildContext context, CalidadState state) {
          return switch (state) {
            CalidadCargando() => const _Esqueleto(),
            CalidadError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () => context.read<CalidadCubit>().recargar(),
                ),
              ],
            ),
            CalidadListo() => _Contenido(estado: state),
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
          SkeletonBlock(alto: 160, radio: 16),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 160, radio: 16),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 120, radio: 16),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado});

  final CalidadListo estado;

  @override
  Widget build(BuildContext context) {
    final ResumenCalidad r = estado.resumen;

    return RefreshIndicator(
      onRefresh: () => context.read<CalidadCubit>().recargar(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          _SelectorMes(mes: estado.filtro.desde),
          const SizedBox(height: AppSpacing.x2),
          _PanelFiltros(estado: estado),
          const SizedBox(height: AppSpacing.x3),
          _Hero(resumen: r),
          if (estado.recurrentes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            _Recurrentes(alertas: estado.recurrentes),
          ],
          if (r.viajesEvaluados > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            _Dimensiones(resumen: r),
          ],
          const SizedBox(height: AppSpacing.x3),
          _Ranking(porDimension: estado.porDimension),
          const SizedBox(height: AppSpacing.x3),
          const _Criterios(),
        ],
      ),
    );
  }
}

class _SelectorMes extends StatelessWidget {
  const _SelectorMes({required this.mes});

  final DateTime mes;

  @override
  Widget build(BuildContext context) {
    final DateTime hoy = DateTime.now();
    final bool esMesActual = mes.year == hoy.year && mes.month == hoy.month;

    return Row(
      children: <Widget>[
        const Expanded(child: Text('Período', style: AppTypography.subtitle)),
        IconButton(
          onPressed: () => context.read<CalidadCubit>().irAMesAnterior(),
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: 'Mes anterior',
          color: AppColors.primary,
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            '${_mesesEs[mes.month - 1]} ${mes.year}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: esMesActual
              ? null
              : () => context.read<CalidadCubit>().irAMesSiguiente(),
          icon: const Icon(LucideIcons.chevronRight),
          tooltip: 'Mes siguiente',
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _PanelFiltros extends StatelessWidget {
  const _PanelFiltros({required this.estado});

  final CalidadListo estado;

  @override
  Widget build(BuildContext context) {
    final FiltroReporte f = estado.filtro;
    final bool hayFiltros =
        f.clienteId != null ||
        f.conductorId != null ||
        f.vehiculoId != null ||
        (f.ruta != null && f.ruta!.isNotEmpty);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              0,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            leading: const Icon(LucideIcons.listFilter, size: 20),
            title: const Text('Filtros', style: AppTypography.subtitle),
            subtitle: Text(
              hayFiltros
                  ? '${formatearFecha(f.desde)} – ${formatearFecha(f.hasta)} · con filtros'
                  : '${formatearFecha(f.desde)} – ${formatearFecha(f.hasta)}',
              style: AppTypography.caption,
            ),
            children: <Widget>[
              FiltrosReporteCard(
                conCard: false,
                filtro: f,
                opciones: estado.opciones,
                alCambiar: (FiltroReporte nuevo) =>
                    context.read<CalidadCubit>().aplicarFiltro(nuevo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.resumen});

  final ResumenCalidad resumen;

  @override
  Widget build(BuildContext context) {
    final ResumenCalidad r = resumen;
    final bool hayDatos = r.viajesEvaluados > 0;
    final TextStyle tenue = AppTypography.caption.copyWith(
      color: AppColors.onNavy.withValues(alpha: 0.75),
    );
    final double? conformes = r.conformesPct;

    return Semantics(
      container: true,
      label: hayDatos
          ? 'Viajes conformes ${conformes == null ? '' : formatearPorcentaje(conformes)}, '
                '${r.viajesEvaluados} viajes evaluados: ${r.verdes} conformes, '
                '${r.ambares} con mejoras, ${r.rojos} con observación'
          : 'Calidad: sin viajes cerrados en el período',
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
              Text(
                'Viajes conformes',
                style: AppTypography.label.copyWith(
                  color: AppColors.onNavy.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              if (hayDatos) ...<Widget>[
                Text(
                  conformes == null ? '—' : formatearPorcentaje(conformes),
                  style: AppTypography.hero.copyWith(color: AppColors.onNavy),
                ),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x4,
                  runSpacing: AppSpacing.x2,
                  children: <Widget>[
                    _CifraHero(
                      etiqueta: 'Viajes evaluados',
                      valor: '${r.viajesEvaluados}',
                    ),
                    _CifraHero(
                      etiqueta: 'Puntaje promedio',
                      valor: r.puntajePromedio == null
                          ? '—'
                          : '${r.puntajePromedio!.round()} de 100',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: <Widget>[
                    _ConteoNivel(nivel: NivelCalidad.verde, cantidad: r.verdes),
                    _ConteoNivel(
                      nivel: NivelCalidad.ambar,
                      cantidad: r.ambares,
                    ),
                    _ConteoNivel(nivel: NivelCalidad.rojo, cantidad: r.rojos),
                  ],
                ),
              ] else ...<Widget>[
                Text(
                  'Sin viajes evaluados',
                  style: AppTypography.title.copyWith(color: AppColors.onNavy),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'La calidad se calcula con los viajes cerrados del '
                  'período.',
                  style: tenue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CifraHero extends StatelessWidget {
  const _CifraHero({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          etiqueta,
          style: AppTypography.caption.copyWith(
            color: AppColors.onNavy.withValues(alpha: 0.75),
          ),
        ),
        Text(
          valor,
          style: AppTypography.subtitle.copyWith(
            color: AppColors.onNavy,
            fontFeatures: AppTypography.tabular,
          ),
        ),
      ],
    );
  }
}

/// Conteo de viajes de un nivel: el badge del nivel con su cantidad.
class _ConteoNivel extends StatelessWidget {
  const _ConteoNivel({required this.nivel, required this.cantidad});

  final NivelCalidad nivel;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: nivel.fondo,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(nivel.icono, size: 14, color: nivel.color),
          const SizedBox(width: AppSpacing.x1),
          Text(
            '$cantidad ${nivel.etiqueta}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alertas recurrentes: 3 o más viajes del mes con la misma dimensión en rojo.
class _Recurrentes extends StatelessWidget {
  const _Recurrentes({required this.alertas});

  final List<AlertaRecurrente> alertas;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      stripe: AppCardStripe.left,
      stripeColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Alertas recurrentes', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            '3 o más viajes cerrados del mes con la misma falla.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x3),
          for (final AlertaRecurrente a in alertas)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          a.mensaje,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${a.viajes} viajes en el mes',
                          style: AppTypography.caption,
                        ),
                      ],
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

/// Cuántos viajes del período fallaron (rojo) en cada dimensión.
class _Dimensiones extends StatelessWidget {
  const _Dimensiones({required this.resumen});

  final ResumenCalidad resumen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Dónde fallan los viajes', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            'Viajes con la dimensión en rojo.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x3),
          _BarraFalla(
            etiqueta: 'Puntualidad',
            fallas: resumen.puntualidadRojos,
            total: resumen.viajesEvaluados,
          ),
          _BarraFalla(
            etiqueta: 'Rentabilidad',
            fallas: resumen.rentabilidadRojos,
            total: resumen.viajesEvaluados,
          ),
          _BarraFalla(
            etiqueta: 'Cliente',
            fallas: resumen.satisfaccionRojos,
            total: resumen.viajesEvaluados,
          ),
          _BarraFalla(
            etiqueta: 'Incidencias',
            fallas: resumen.incidenciasRojos,
            total: resumen.viajesEvaluados,
          ),
        ],
      ),
    );
  }
}

class _BarraFalla extends StatelessWidget {
  const _BarraFalla({
    required this.etiqueta,
    required this.fallas,
    required this.total,
  });

  final String etiqueta;
  final int fallas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Semantics(
        label: '$etiqueta: $fallas de $total viajes en rojo',
        child: ExcludeSemantics(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 100,
                child: Text(etiqueta, style: AppTypography.body),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : fallas / total,
                    minHeight: 10,
                    color: fallas == 0 ? AppColors.success : AppColors.error,
                    backgroundColor: AppColors.navyTint,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              SizedBox(
                width: 48,
                child: Text(
                  '$fallas/$total',
                  textAlign: TextAlign.right,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ranking por ruta, conductor o placa, de menor a mayor puntaje para ver
/// primero dónde hay que actuar.
class _Ranking extends StatefulWidget {
  const _Ranking({required this.porDimension});

  final Map<DimensionCalidad, List<CalidadDimension>> porDimension;

  @override
  State<_Ranking> createState() => _RankingState();
}

class _RankingState extends State<_Ranking> {
  DimensionCalidad _dimension = DimensionCalidad.conductor;

  @override
  Widget build(BuildContext context) {
    final List<CalidadDimension> filas =
        widget.porDimension[_dimension] ?? const <CalidadDimension>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Calidad por', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            'De menor a mayor puntaje: arriba, lo que más atención necesita.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: <Widget>[
              for (final DimensionCalidad d in DimensionCalidad.values)
                ChipOpcion(
                  etiqueta: d.etiqueta,
                  seleccionado: d == _dimension,
                  onTap: () => setState(() => _dimension = d),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          if (filas.isEmpty)
            const Text(
              'Todavía no hay viajes cerrados en este período.',
              style: AppTypography.caption,
            )
          else
            for (final CalidadDimension f in filas) _FilaRanking(fila: f),
        ],
      ),
    );
  }
}

class _FilaRanking extends StatelessWidget {
  const _FilaRanking({required this.fila});

  final CalidadDimension fila;

  @override
  Widget build(BuildContext context) {
    final List<String> fallas = <String>[
      if (fila.puntualidadRojos > 0) 'retrasos ${fila.puntualidadRojos}',
      if (fila.rentabilidadRojos > 0) 'sobrecostos ${fila.rentabilidadRojos}',
      if (fila.satisfaccionRojos > 0) 'cliente ${fila.satisfaccionRojos}',
      if (fila.incidenciasRojos > 0) 'incidencias ${fila.incidenciasRojos}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fila.clave,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${fila.viajes} ${fila.viajes == 1 ? 'viaje' : 'viajes'}'
                  '${fallas.isEmpty ? '' : ' · en rojo: ${fallas.join(', ')}'}',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.x1),
                NivelCalidadBadge(
                  nivel: NivelCalidad.dePuntaje(fila.puntajePromedio),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            fila.puntajePromedio == null
                ? '—'
                : '${fila.puntajePromedio!.round()}',
            style: AppTypography.subtitle.copyWith(
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cómo se califica un viaje, para que el administrador sepa qué mira cada
/// color. Los umbrales los decide el servidor; aquí solo se explican.
class _Criterios extends StatelessWidget {
  const _Criterios();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Cómo se califica', style: AppTypography.subtitle),
          SizedBox(height: AppSpacing.x2),
          Text(
            'Puntualidad: llegada real contra el tiempo estimado y su margen.',
            style: AppTypography.caption,
          ),
          Text(
            'Rentabilidad: costo real contra el estimado (ámbar sobre 15 %, '
            'rojo sobre 35 % o si el costo supera el flete).',
            style: AppTypography.caption,
          ),
          Text(
            'Cliente: calificación de la encuesta, cuando responde.',
            style: AppTypography.caption,
          ),
          Text(
            'Incidencias: desvíos, paradas largas, pausas ignoradas y fallas '
            'de checklist del viaje.',
            style: AppTypography.caption,
          ),
          SizedBox(height: AppSpacing.x2),
          Text(
            'Cada dimensión suma 2 (verde), 1 (ámbar) o 0 (rojo); el '
            'promedio da el puntaje de 0 a 100: 75 o más conforme, 40 o más '
            'con mejoras, menos con observación. Una dimensión sin datos no '
            'cuenta.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
