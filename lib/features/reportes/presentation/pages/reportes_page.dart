import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../calidad/domain/repositories/calidad_repository.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../dashboard/domain/entities/metricas.dart';
import '../../../dashboard/domain/repositories/metricas_repository.dart';
import '../../../esperas/domain/repositories/espera_repository.dart';
import '../../../satisfaccion/domain/repositories/satisfaccion_repository.dart';
import '../../../vehiculos/domain/repositories/hoja_vida_repository.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../viajes/domain/repositories/rentabilidad_repository.dart';
import '../../domain/entities/informe.dart';
import '../../domain/repositories/reporte_repository.dart';
import '../../domain/usecases/cargar_opciones_reporte_use_case.dart';
import '../../domain/usecases/informes_use_cases.dart';
import '../../domain/usecases/reporte_use_cases.dart';
import '../bloc/reportes_cubit.dart';
import '../widgets/filtros_reporte_card.dart';

/// Informes del administrador con filtros (RF-27) y exportación a PDF
/// (RF-28). El tipo de informe decide qué filtros y agrupaciones se ofrecen.
class ReportesPage extends StatelessWidget {
  const ReportesPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final ClienteRepository clientes = context.read<ClienteRepository>();
    final ConductorRepository conductores = context.read<ConductorRepository>();
    final VehiculoRepository vehiculos = context.read<VehiculoRepository>();
    final RentabilidadRepository rentabilidad = context
        .read<RentabilidadRepository>();
    final MetricasRepository metricas = context.read<MetricasRepository>();
    final CalidadRepository calidad = context.read<CalidadRepository>();
    final SatisfaccionRepository satisfaccion = context
        .read<SatisfaccionRepository>();

    return BlocProvider<ReportesCubit>(
      create: (BuildContext context) => ReportesCubit(
        obtener: ObtenerInformeUseCase(<TipoInforme, ConstructorInforme>{
          TipoInforme.viajes: InformeViajes(context.read<ReporteRepository>()),
          TipoInforme.estadoResultados: InformeEstadoResultados(rentabilidad),
          TipoInforme.rentabilidad: InformeRentabilidad(metricas),
          TipoInforme.costos: InformeCostos(rentabilidad),
          TipoInforme.puntualidad: InformePuntualidad(metricas),
          TipoInforme.esperas: InformeEsperas(context.read<EsperaRepository>()),
          TipoInforme.flota: InformeFlota(
            vehiculos,
            context.read<HojaVidaRepository>(),
          ),
          TipoInforme.conductores: InformeConductores(
            metricas,
            calidad,
            satisfaccion,
          ),
          TipoInforme.satisfaccion: InformeSatisfaccion(satisfaccion),
          TipoInforme.calidad: InformeCalidad(calidad),
        }),
        exportar: ExportarReportePdfUseCase(context.read<ExportadorReporte>()),
        hoy: DateTime.now(),
        cargarOpciones: CargarOpcionesReporteUseCase(
          clientes: clientes,
          conductores: conductores,
          vehiculos: vehiculos,
        ).call,
      ),
      child: AdminScaffold(
        titulo: 'Reportes',
        seccionActual: AdminSection.reportes,
        usuario: usuario,
        body: const _Contenido(),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportesCubit, ReportesState>(
      builder: (BuildContext context, ReportesState s) {
        final ReportesCubit cubit = context.read<ReportesCubit>();
        final Informe? informe = s.informe;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: <Widget>[
            _SelectorInforme(estado: s),
            if (s.tipo.usaFechas || s.tipo.campos.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              FiltrosReporteCard(
                filtro: s.filtro,
                opciones: s.opciones,
                conFechas: s.tipo.usaFechas,
                campos: s.tipo.campos,
                alCambiar: cubit.aplicarFiltro,
              ),
            ],
            const SizedBox(height: AppSpacing.x3),
            if (s.mensaje != null) ...<Widget>[
              AppAlert(mensaje: s.mensaje!),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (s.estado == EstadoReporte.cargando)
              const SkeletonBlock(alto: 160, radio: 16)
            else if (s.estado == EstadoReporte.listo && informe != null)
              if (informe.filas.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icono: LucideIcons.fileText,
                    titulo: 'Sin datos para estos filtros',
                    mensaje: 'Prueba con otro rango de fechas o quita filtros.',
                  ),
                )
              else ...<Widget>[
                _TablaInforme(informe: informe),
                const SizedBox(height: AppSpacing.x3),
                PrimaryActionButton(
                  label: 'Exportar PDF',
                  leadingIcon: LucideIcons.fileDown,
                  loading: s.exportando,
                  onPressed: cubit.exportarPdf,
                ),
              ],
          ],
        );
      },
    );
  }
}

/// Elige el informe y, si admite varias, la agrupación.
class _SelectorInforme extends StatelessWidget {
  const _SelectorInforme({required this.estado});

  final ReportesState estado;

  Future<T?> _elegir<T>(
    BuildContext context,
    String titulo,
    List<(T, String)> opciones,
  ) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Text(titulo, style: AppTypography.subtitle),
            ),
            for (final (T valor, String texto) in opciones)
              ListTile(
                title: Text(texto),
                onTap: () => Navigator.of(ctx).pop(valor),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReportesCubit cubit = context.read<ReportesCubit>();
    final TipoInforme tipo = estado.tipo;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSelectField(
            label: 'Informe',
            icono: LucideIcons.fileText,
            valor: tipo.etiqueta,
            onTap: () async {
              final TipoInforme? elegido = await _elegir<TipoInforme>(
                context,
                'Informe',
                <(TipoInforme, String)>[
                  for (final TipoInforme t in TipoInforme.values)
                    (t, t.etiqueta),
                ],
              );
              if (elegido != null) await cubit.cambiarTipo(elegido);
            },
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(tipo.descripcion, style: AppTypography.caption),
          if (tipo.dimensiones.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            AppSelectField(
              label: 'Agrupar por',
              valor: estado.dimension.etiqueta,
              onTap: () async {
                final DimensionMetrica? elegida =
                    await _elegir<DimensionMetrica>(
                      context,
                      'Agrupar por',
                      <(DimensionMetrica, String)>[
                        for (final DimensionMetrica d in tipo.dimensiones)
                          (d, d.etiqueta),
                      ],
                    );
                if (elegida != null) await cubit.cambiarDimension(elegida);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Tabla con desplazamiento horizontal, resumen y notas del informe.
class _TablaInforme extends StatelessWidget {
  const _TablaInforme({required this.informe});

  final Informe informe;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      stripe: AppCardStripe.left,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(informe.titulo, style: AppTypography.subtitle),
          if (informe.resumen != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x1),
            Text(
              informe.resumen!,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.x3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: AppSpacing.x4,
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 56,
              dividerThickness: 0.5,
              headingTextStyle: AppTypography.label,
              dataTextStyle: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontFeatures: AppTypography.tabular,
              ),
              columns: <DataColumn>[
                for (int i = 0; i < informe.columnas.length; i++)
                  DataColumn(
                    label: Text(informe.columnas[i]),
                    numeric: informe.numericas.contains(i),
                  ),
              ],
              rows: <DataRow>[
                for (final List<String> fila in informe.filas)
                  DataRow(
                    cells: <DataCell>[
                      for (final String celda in fila) DataCell(Text(celda)),
                    ],
                  ),
              ],
            ),
          ),
          for (final String nota in informe.notas) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            Text(nota, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}
