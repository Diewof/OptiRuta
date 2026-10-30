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
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../dashboard/domain/entities/metricas.dart';
import '../../../reportes/domain/entities/reporte.dart';
import '../../../reportes/domain/usecases/cargar_opciones_reporte_use_case.dart';
import '../../../reportes/presentation/widgets/filtros_reporte_card.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/satisfaccion.dart';
import '../../domain/repositories/satisfaccion_repository.dart';
import '../../domain/usecases/satisfaccion_use_cases.dart';
import '../bloc/satisfaccion_cubit.dart';
import '../bloc/satisfaccion_state.dart';

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

String _decimal(double valor) => valor.toStringAsFixed(1).replaceAll('.', ',');

/// Satisfacción del cliente (pestaña del Resumen): resultados de la encuesta
/// que se envía al finalizar cada viaje. Los costos y la rentabilidad viven en
/// la otra pestaña; aquí no se mezclan.
class SatisfaccionPage extends StatelessWidget {
  const SatisfaccionPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SatisfaccionCubit>(
      create: (BuildContext context) {
        final SatisfaccionRepository repo = context
            .read<SatisfaccionRepository>();
        return SatisfaccionCubit(
          resumen: ObtenerResumenSatisfaccionUseCase(repo),
          porDimension: ObtenerSatisfaccionPorDimensionUseCase(repo),
          comentarios: ListarComentariosSatisfaccionUseCase(repo),
          cargarOpciones: CargarOpcionesReporteUseCase(
            clientes: context.read<ClienteRepository>(),
            conductores: context.read<ConductorRepository>(),
            vehiculos: context.read<VehiculoRepository>(),
          ).call,
        );
      },
      child: _SatisfaccionView(usuario: usuario),
    );
  }
}

class _SatisfaccionView extends StatelessWidget {
  const _SatisfaccionView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Resumen',
      seccionActual: AdminSection.satisfaccion,
      usuario: usuario,
      body: BlocBuilder<SatisfaccionCubit, SatisfaccionState>(
        builder: (BuildContext context, SatisfaccionState state) {
          return switch (state) {
            SatisfaccionCargando() => const _Esqueleto(),
            SatisfaccionError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () =>
                      context.read<SatisfaccionCubit>().recargar(),
                ),
              ],
            ),
            SatisfaccionListo() => _Contenido(estado: state),
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

  final SatisfaccionListo estado;

  @override
  Widget build(BuildContext context) {
    final ResumenSatisfaccion r = estado.resumen;

    return RefreshIndicator(
      onRefresh: () => context.read<SatisfaccionCubit>().recargar(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          _SelectorMes(mes: estado.filtro.desde),
          const SizedBox(height: AppSpacing.x2),
          _PanelFiltros(estado: estado),
          const SizedBox(height: AppSpacing.x3),
          _Hero(resumen: r),
          if (r.respondidas > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            _Dimensiones(resumen: r),
            const SizedBox(height: AppSpacing.x3),
            _Puntualidad(resumen: r),
          ],
          const SizedBox(height: AppSpacing.x3),
          _Cobertura(resumen: r),
          const SizedBox(height: AppSpacing.x3),
          _Ranking(porDimension: estado.porDimension),
          const SizedBox(height: AppSpacing.x3),
          _Comentarios(comentarios: estado.comentarios),
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
          onPressed: () => context.read<SatisfaccionCubit>().irAMesAnterior(),
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
              : () => context.read<SatisfaccionCubit>().irAMesSiguiente(),
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

  final SatisfaccionListo estado;

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
                    context.read<SatisfaccionCubit>().aplicarFiltro(nuevo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insignia de nivel: icono + etiqueta, nunca solo color.
class _NivelBadge extends StatelessWidget {
  const _NivelBadge({required this.nivel});

  final NivelSatisfaccion nivel;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color fondo, IconData icono) = switch (nivel) {
      NivelSatisfaccion.bueno => (
        AppColors.success,
        AppColors.successTint,
        LucideIcons.circleCheck,
      ),
      NivelSatisfaccion.regular => (
        AppColors.warning,
        AppColors.warningTint,
        LucideIcons.triangleAlert,
      ),
      NivelSatisfaccion.bajo => (
        AppColors.error,
        AppColors.errorTint,
        LucideIcons.circleX,
      ),
      NivelSatisfaccion.sinDatos => (
        AppColors.textSecondary,
        AppColors.navyTint,
        LucideIcons.circleDashed,
      ),
    };
    return Semantics(
      label: 'Nivel: ${nivel.etiqueta}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: AppRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 14, color: color),
              const SizedBox(width: AppSpacing.x1),
              Text(
                nivel.etiqueta,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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

  final ResumenSatisfaccion resumen;

  @override
  Widget build(BuildContext context) {
    final ResumenSatisfaccion r = resumen;
    final bool hayDatos = r.hayDatosSuficientes;
    final TextStyle tenue = AppTypography.caption.copyWith(
      color: AppColors.onNavy.withValues(alpha: 0.75),
    );
    final double? nps = r.nps;

    return Semantics(
      container: true,
      label: hayDatos
          ? 'Satisfacción global ${_decimal(r.csatGlobal ?? 0)} de 5, '
                'recomendación ${nps?.round()} sobre 100, '
                '${r.respondidas} respuestas'
          : 'Satisfacción: sin datos suficientes, ${r.respondidas} respuestas',
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
                'Satisfacción global',
                style: AppTypography.label.copyWith(
                  color: AppColors.onNavy.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              if (hayDatos) ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      _decimal(r.csatGlobal ?? 0),
                      style: AppTypography.hero.copyWith(
                        color: AppColors.onNavy,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.x1,
                        bottom: 6,
                      ),
                      child: Text('de 5', style: tenue),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x4,
                  runSpacing: AppSpacing.x2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _CifraHero(
                      etiqueta: 'Recomendación (NPS)',
                      valor: nps == null ? '—' : '${nps.round()}',
                    ),
                    _CifraHero(
                      etiqueta: 'Respuestas',
                      valor: '${r.respondidas}',
                    ),
                    _CifraHero(
                      etiqueta: 'Tasa de respuesta',
                      valor: r.tasaRespuestaPct == null
                          ? '—'
                          : formatearPorcentaje(r.tasaRespuestaPct!),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: <Widget>[
                    _NivelBadge(nivel: NivelSatisfaccion.deCsat(r.csatGlobal)),
                    _NivelBadge(nivel: NivelSatisfaccion.deNps(nps)),
                  ],
                ),
              ] else ...<Widget>[
                Text(
                  'Sin datos suficientes',
                  style: AppTypography.title.copyWith(color: AppColors.onNavy),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'Hay ${r.respondidas} '
                  '${r.respondidas == 1 ? 'respuesta' : 'respuestas'} en el '
                  'período; se necesitan al menos '
                  '${ResumenSatisfaccion.minimoRespuestas} para mostrar '
                  'promedios confiables.',
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

/// Promedio de cada dimensión de la encuesta, de 1 a 5.
class _Dimensiones extends StatelessWidget {
  const _Dimensiones({required this.resumen});

  final ResumenSatisfaccion resumen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Calificación por aspecto', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          const Text('Promedio de 1 a 5.', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.x3),
          _BarraDimension(etiqueta: 'Entrega', valor: resumen.csatEntrega),
          _BarraDimension(etiqueta: 'Servicio', valor: resumen.csatServicio),
          _BarraDimension(etiqueta: 'Atención', valor: resumen.csatAtencion),
          _BarraDimension(
            etiqueta: 'Puntualidad',
            valor: resumen.csatPuntualidad,
          ),
        ],
      ),
    );
  }
}

class _BarraDimension extends StatelessWidget {
  const _BarraDimension({required this.etiqueta, required this.valor});

  final String etiqueta;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    final double v = valor ?? 0;
    final Color color = switch (NivelSatisfaccion.deCsat(valor)) {
      NivelSatisfaccion.bueno => AppColors.success,
      NivelSatisfaccion.regular => AppColors.warning,
      NivelSatisfaccion.bajo => AppColors.error,
      NivelSatisfaccion.sinDatos => AppColors.textDisabled,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Semantics(
        label:
            '$etiqueta: ${valor == null ? 'sin datos' : '${_decimal(v)} de 5'}',
        child: ExcludeSemantics(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 92,
                child: Text(etiqueta, style: AppTypography.body),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: v / 5,
                    minHeight: 10,
                    color: color,
                    backgroundColor: AppColors.navyTint,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              SizedBox(
                width: 36,
                child: Text(
                  valor == null ? '—' : _decimal(v),
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

/// Puntualidad medida (hitos vs tiempo estimado) frente a la que el cliente
/// percibió: si divergen, el problema es de expectativa y no de operación.
class _Puntualidad extends StatelessWidget {
  const _Puntualidad({required this.resumen});

  final ResumenSatisfaccion resumen;

  @override
  Widget build(BuildContext context) {
    final double? real = resumen.puntualidadRealPct;
    final double? percibida = resumen.puntualidadPercibidaPct;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Tiempos de entrega vs. pronóstico',
            style: AppTypography.subtitle,
          ),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            'Real: llegó dentro del tiempo estimado más su margen. '
            'Percibida: el cliente calificó la puntualidad con 4 o 5.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Indicador(
                etiqueta: 'Puntualidad real',
                valor: real == null ? 'Sin datos' : formatearPorcentaje(real),
                detalle: real == null
                    ? null
                    : '${resumen.viajesATiempo} de ${resumen.viajesMedidos} viajes',
              ),
              _Indicador(
                etiqueta: 'Puntualidad percibida',
                valor: percibida == null
                    ? 'Sin datos'
                    : formatearPorcentaje(percibida),
                detalle:
                    '${resumen.puntualidadPercibida} de ${resumen.respondidas} respuestas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.etiqueta, required this.valor, this.detalle});

  final String etiqueta;
  final String valor;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(etiqueta, style: AppTypography.caption),
          const SizedBox(height: 2),
          Text(
            valor,
            style: AppTypography.subtitle.copyWith(
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (detalle != null) Text(detalle!, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// Cuántas encuestas se respondieron y por qué las demás no: sin esto un CSAT
/// alto con 2 respuestas de 20 parecería mejor de lo que es.
class _Cobertura extends StatelessWidget {
  const _Cobertura({required this.resumen});

  final ResumenSatisfaccion resumen;

  @override
  Widget build(BuildContext context) {
    final ResumenSatisfaccion r = resumen;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Cobertura de la encuesta', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          Text(
            r.encuestasTotal == 0
                ? 'Todavía no se generó ninguna encuesta en este período.'
                : '${r.encuestasTotal} '
                      '${r.encuestasTotal == 1 ? 'encuesta generada' : 'encuestas generadas'} '
                      'al finalizar viajes.',
            style: AppTypography.caption,
          ),
          if (r.encuestasTotal > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Indicador(etiqueta: 'Respondidas', valor: '${r.respondidas}'),
                _Indicador(etiqueta: 'Esperando', valor: '${r.pendientes}'),
                _Indicador(etiqueta: 'Sin respuesta', valor: '${r.vencidas}'),
              ],
            ),
            if (r.sinContacto > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      '${r.sinContacto} '
                      '${r.sinContacto == 1 ? 'cliente no tiene' : 'clientes no tienen'} '
                      'correo registrado: agrégalo en Personas → Clientes '
                      'para que la encuesta se envíe sola.',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Ranking por ruta, cliente o conductor, de menor a mayor satisfacción para
/// ver primero dónde hay que actuar.
class _Ranking extends StatefulWidget {
  const _Ranking({required this.porDimension});

  final Map<DimensionMetrica, List<SatisfaccionDimension>> porDimension;

  @override
  State<_Ranking> createState() => _RankingState();
}

class _RankingState extends State<_Ranking> {
  DimensionMetrica _dimension = DimensionMetrica.conductor;

  @override
  Widget build(BuildContext context) {
    final List<SatisfaccionDimension> filas =
        widget.porDimension[_dimension] ?? const <SatisfaccionDimension>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Satisfacción por', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          const Text(
            'De menor a mayor: arriba, lo que más atención necesita.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: <Widget>[
              for (final DimensionMetrica d in dimensionesSatisfaccion)
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
              'Todavía no hay respuestas en este período.',
              style: AppTypography.caption,
            )
          else
            for (final SatisfaccionDimension f in filas) _FilaRanking(fila: f),
        ],
      ),
    );
  }
}

class _FilaRanking extends StatelessWidget {
  const _FilaRanking({required this.fila});

  final SatisfaccionDimension fila;

  @override
  Widget build(BuildContext context) {
    final String respuestas = fila.respondidas == 1
        ? '1 respuesta'
        : '${fila.respondidas} respuestas';
    // Con pocas respuestas el promedio engaña: se dice, no se oculta.
    final NivelSatisfaccion nivel =
        fila.respondidas < ResumenSatisfaccion.minimoRespuestas
        ? NivelSatisfaccion.sinDatos
        : NivelSatisfaccion.deCsat(fila.csatGlobal);

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
                  fila.nps == null
                      ? respuestas
                      : '$respuestas · NPS ${fila.nps!.round()}',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.x1),
                _NivelBadge(nivel: nivel),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            fila.csatGlobal == null ? '—' : _decimal(fila.csatGlobal!),
            style: AppTypography.subtitle.copyWith(
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _Comentarios extends StatelessWidget {
  const _Comentarios({required this.comentarios});

  final List<ComentarioSatisfaccion> comentarios;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Comentarios de clientes', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x2),
          if (comentarios.isEmpty)
            const EmptyState(
              icono: LucideIcons.messageSquareText,
              mensaje:
                  'Los comentarios que dejen los clientes aparecerán aquí.',
            )
          else
            for (final ComentarioSatisfaccion c in comentarios)
              _FilaComentario(comentario: c),
        ],
      ),
    );
  }
}

class _FilaComentario extends StatelessWidget {
  const _FilaComentario({required this.comentario});

  final ComentarioSatisfaccion comentario;

  @override
  Widget build(BuildContext context) {
    final ComentarioSatisfaccion c = comentario;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  c.cliente,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _NivelBadge(nivel: NivelSatisfaccion.deCsat(c.csatGlobal)),
            ],
          ),
          Text(
            '${c.ruta} · ${c.conductor} · ${formatearFecha(c.fechaRespuesta)}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text('“${c.comentario}”', style: AppTypography.body),
        ],
      ),
    );
  }
}
