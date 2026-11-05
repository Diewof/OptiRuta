import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/admin_shell_scope.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/ilustracion_estado.dart';
import '../../../../core/widgets/kpi_tile.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../notificaciones/domain/repositories/notificacion_repository.dart';
import '../../../notificaciones/domain/usecases/listar_notificaciones_use_case.dart';
import '../../../vehiculos/domain/repositories/vehiculo_repository.dart';
import '../../../viajes/domain/entities/viaje_resumen.dart';
import '../../../viajes/domain/repositories/viaje_repository.dart';
import '../../../viajes/domain/usecases/listar_viajes_activos_use_case.dart';
import '../../../viajes/presentation/pages/viaje_detalle_page.dart';
import '../../../viajes/presentation/widgets/viaje_resumen_card.dart';
import '../bloc/inicio_cubit.dart';
import '../widgets/metricas_widgets.dart';

/// Vista inicial del Administrador: lo urgente primero. Alertas sin leer,
/// todos los viajes en curso y tres cifras del momento. El análisis del
/// período (costos, calidad, etc.) vive en Análisis.
class InicioPage extends StatelessWidget {
  const InicioPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InicioCubit>(
      create: (BuildContext context) => InicioCubit(
        listarNotificaciones: ListarNotificacionesUseCase(
          context.read<NotificacionRepository>(),
        ),
        listarViajesActivos: ListarViajesActivosUseCase(
          context.read<ViajeRepository>(),
        ),
        vehiculoRepository: context.read<VehiculoRepository>(),
      ),
      child: _InicioView(usuario: usuario),
    );
  }
}

class _InicioView extends StatefulWidget {
  const _InicioView({required this.usuario});

  final Usuario usuario;

  @override
  State<_InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<_InicioView> {
  ValueListenable<AdminSection>? _seccion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueListenable<AdminSection>? nueva = AdminShellScope.maybeOf(
      context,
    )?.actual;
    if (identical(nueva, _seccion)) return;
    _seccion?.removeListener(_alCambiarSeccion);
    _seccion = nueva;
    nueva?.addListener(_alCambiarSeccion);
  }

  /// El shell mantiene Inicio vivo: al volver a él se refrescan alertas y
  /// viajes sin mostrar el esqueleto.
  void _alCambiarSeccion() {
    if (_seccion?.value == AdminSection.inicio) {
      context.read<InicioCubit>().cargar(silencioso: true);
    }
  }

  @override
  void dispose() {
    _seccion?.removeListener(_alCambiarSeccion);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Inicio',
      seccionActual: AdminSection.inicio,
      usuario: widget.usuario,
      body: BlocBuilder<InicioCubit, InicioState>(
        builder: (BuildContext context, InicioState state) {
          return switch (state) {
            InicioCargando() => const _Esqueleto(),
            InicioError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () => context.read<InicioCubit>().cargar(),
                ),
              ],
            ),
            InicioListo() => _Contenido(estado: state),
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: const <Widget>[
        SkeletonBlock(alto: 88),
        SizedBox(height: AppSpacing.x3),
        SkeletonBlock(alto: 120),
        SizedBox(height: AppSpacing.x3),
        SkeletonBlock(alto: 120),
      ],
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado});

  final InicioListo estado;

  @override
  Widget build(BuildContext context) {
    final int enCurso = estado.viajesActivos.length;

    return RefreshIndicator(
      onRefresh: () => context.read<InicioCubit>().cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: KpiTile(
                  etiqueta: 'En curso',
                  valor: '$enCurso',
                  icono: LucideIcons.truck,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: KpiTile(
                  etiqueta: 'Flota en ruta',
                  valor: '${estado.vehiculosEnRuta}/${estado.totalVehiculos}',
                  icono: LucideIcons.route,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: KpiTile(
                  etiqueta: 'Sin leer',
                  valor: '${estado.alertas.length}',
                  icono: LucideIcons.bell,
                  stripeColor: estado.alertas.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          if (estado.alertas.isNotEmpty) ...<Widget>[
            AlertasActivasCard(alertas: estado.alertas),
            const SizedBox(height: AppSpacing.x4),
          ],
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
                onTap: () {
                  final InicioCubit cubit = context.read<InicioCubit>();
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
              const SizedBox(height: AppSpacing.x2),
            ],
        ],
      ),
    );
  }
}
