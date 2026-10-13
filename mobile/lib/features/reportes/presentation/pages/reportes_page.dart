import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../clientes/domain/repositories/cliente_repository.dart';
import '../../../conductores/domain/repositories/conductor_repository.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../domain/entities/reporte.dart';
import '../../domain/repositories/reporte_repository.dart';
import '../../domain/usecases/cargar_opciones_reporte_use_case.dart';
import '../../domain/usecases/reporte_use_cases.dart';
import '../bloc/reportes_cubit.dart';
import '../widgets/filtros_reporte_card.dart';

/// Reporte de viajes cerrados con filtros por fecha, ruta, cliente, conductor
/// y vehículo (RF-27) y exportación a PDF (RF-28).
class ReportesPage extends StatelessWidget {
  const ReportesPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final ClienteRepository clientes = context.read<ClienteRepository>();
    final ConductorRepository conductores = context.read<ConductorRepository>();
    final VehiculoRepository vehiculos = context.read<VehiculoRepository>();

    return BlocProvider<ReportesCubit>(
      create: (BuildContext context) => ReportesCubit(
        obtener: ObtenerReporteViajesUseCase(context.read<ReporteRepository>()),
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
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: <Widget>[
            FiltrosReporteCard(
              filtro: s.filtro,
              opciones: s.opciones,
              alCambiar: (FiltroReporte f) =>
                  context.read<ReportesCubit>().aplicarFiltro(f),
            ),
            const SizedBox(height: AppSpacing.x3),
            if (s.mensaje != null) ...<Widget>[
              AppAlert(mensaje: s.mensaje!),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (s.estado == EstadoReporte.cargando)
              const SkeletonBlock(alto: 160, radio: 16)
            else if (s.estado == EstadoReporte.listo && s.filas.isEmpty)
              const AppCard(
                child: EmptyState(
                  icono: LucideIcons.fileText,
                  titulo: 'Sin viajes para estos filtros',
                  mensaje: 'Prueba con otro rango de fechas o quita filtros.',
                ),
              )
            else if (s.estado == EstadoReporte.listo) ...<Widget>[
              _Totales(totales: s.totales),
              const SizedBox(height: AppSpacing.x3),
              for (final FilaReporte f in s.filas) ...<Widget>[
                _FilaViaje(fila: f),
                const SizedBox(height: AppSpacing.x2),
              ],
              const SizedBox(height: AppSpacing.x2),
              PrimaryActionButton(
                label: 'Exportar PDF',
                leadingIcon: LucideIcons.fileDown,
                loading: s.exportando,
                onPressed: () => context.read<ReportesCubit>().exportarPdf(),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Totales extends StatelessWidget {
  const _Totales({required this.totales});

  final TotalesReporte totales;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      stripe: AppCardStripe.left,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            totales.viajes == 1 ? '1 viaje' : '${totales.viajes} viajes',
            style: AppTypography.subtitle,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Flete ${formatearMillones(totales.valorFlete)} · '
            'Costos ${formatearMillones(totales.costos)}',
            style: AppTypography.body,
          ),
          Text(
            'Rentabilidad ${formatearMillones(totales.rentabilidad)} · '
            '${totales.km.round()} km',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FilaViaje extends StatelessWidget {
  const _FilaViaje({required this.fila});

  final FilaReporte fila;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fila.ruta,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${fila.remision} · ${fila.cliente}',
                  style: AppTypography.caption,
                ),
                Text(
                  '${fila.conductor} · ${fila.placa} · '
                  '${formatearFecha(fila.fechaCierre)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Text(
            formatearMillones(fila.rentabilidad),
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: fila.rentabilidad < 0
                  ? AppColors.error
                  : AppColors.textPrimary,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
