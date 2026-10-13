import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/accessibility/announce.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_alert.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/conductor_scaffold.dart';
import '../../../../core/widgets/conductor_section.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/estado_viaje_badge.dart';
import '../../../../core/widgets/ilustracion_estado.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/vehiculo_thumb.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../../checklist/domain/entities/checklist.dart';
import '../../../checklist/domain/repositories/checklist_repository.dart';
import '../../../checklist/domain/usecases/checklist_use_cases.dart';
import '../../../checklist/presentation/pages/checklist_page.dart';
import '../../../vehiculos/domain/entities/tipo_vehiculo.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/costo_viaje_repository.dart';
import '../../domain/repositories/hito_repository.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/servicios/servicio_ubicacion.dart';
import '../../domain/usecases/actualizar_valor_real_costo_use_case.dart';
import '../../domain/usecases/agregar_costo_viaje_use_case.dart';
import '../../domain/usecases/listar_costos_viaje_use_case.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/listar_viajes_activos_use_case.dart';
import '../../domain/usecases/iniciar_viaje_use_case.dart';
import '../../domain/usecases/registrar_hito_use_case.dart';
import '../bloc/conductor_viaje_cubit.dart';
import '../bloc/conductor_viaje_state.dart';
import '../widgets/costos_viaje_card.dart';
import '../widgets/hito_timeline.dart';
import '../widgets/mapa_ruta_viaje.dart';
import '../widgets/registrar_hito_sheet.dart';
import '../bloc/monitor_ruta_registro.dart';
import '../widgets/agregar_costo_sheet.dart';
import '../widgets/valor_real_sheet.dart';

/// Inicio del Conductor: el viaje activo con su ruta estimada, el hilo de
/// hitos y los costos, más la acción principal fija al pie. Registrar un hito
/// toma **dos toques**: el botón y «Confirmar» en la hoja.
///
/// La ruta es una figura estática y estimada (sin tracking GPS, ver CLAUDE.md
/// "Dominio: viajes").
class ConductorInicioPage extends StatelessWidget {
  const ConductorInicioPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConductorViajeCubit>(
      create: (BuildContext context) => ConductorViajeCubit(
        listarActivos: ListarViajesActivosUseCase(
          context.read<ViajeRepository>(),
        ),
        listarHitos: ListarHitosUseCase(context.read<HitoRepository>()),
        listarCostos: ListarCostosViajeUseCase(
          context.read<CostoViajeRepository>(),
        ),
        registrarHito: RegistrarHitoUseCase(context.read<HitoRepository>()),
        iniciarViaje: IniciarViajeUseCase(context.read<ViajeRepository>()),
        ubicacion: context.read<ServicioUbicacion>(),
        actualizarValorReal: ActualizarValorRealCostoUseCase(
          context.read<CostoViajeRepository>(),
        ),
        agregarCosto: AgregarCostoViajeUseCase(
          context.read<CostoViajeRepository>(),
        ),
        obtenerChecklist: ObtenerChecklistViajeUseCase(
          context.read<ChecklistRepository>(),
        ),
      ),
      child: _InicioView(usuario: usuario),
    );
  }
}

class _InicioView extends StatelessWidget {
  const _InicioView({required this.usuario});

  final Usuario usuario;

  static TipoHito? _siguiente(List<Hito> hitos) {
    for (final TipoHito t in HitoTimeline.orden) {
      if (!hitos.any((Hito h) => h.tipo == t)) return t;
    }
    return null;
  }

  /// Qué falta antes de poder registrar la salida. La regla real la aplica
  /// `viaje_iniciar`; esto solo ofrece el paso correcto al conductor.
  static _PasoSalida _pasoSalida(ConductorViajeListo estado, TipoHito? tipo) {
    if (tipo != TipoHito.salida ||
        estado.viaje.estado != EstadoViaje.asignado) {
      return _PasoSalida.registrar;
    }
    final ChecklistViaje? checklist = estado.checklist;
    if (checklist == null || checklist.estaVencido(DateTime.now())) {
      return _PasoSalida.hacerChecklist;
    }
    return checklist.bloqueaSalida
        ? _PasoSalida.esperarAutorizacion
        : _PasoSalida.registrar;
  }

  Future<void> _hacerChecklist(
    BuildContext context,
    ConductorViajeListo estado,
  ) async {
    final ConductorViajeCubit cubit = context.read<ConductorViajeCubit>();
    final ChecklistViaje? hecho = await ChecklistPage.abrir(
      context,
      viajeId: estado.viaje.id,
      tipoVehiculo: estado.viaje.tipoVehiculo ?? TipoVehiculo.dobleTroque,
      placa: estado.viaje.placaVehiculo,
    );
    if (hecho != null) await cubit.cargar(silencioso: true);
  }

  Future<void> _registrar(
    BuildContext context,
    ConductorViajeListo estado,
    TipoHito tipo,
  ) async {
    final ConductorViajeCubit cubit = context.read<ConductorViajeCubit>();
    final bool? ok = await RegistrarHitoSheet.mostrar(
      context,
      tipo: tipo,
      descripcionViaje: '${estado.viaje.origen} → ${estado.viaje.destino}',
      alConfirmar: () => cubit.registrarHito(tipo),
    );
    if (ok == true && context.mounted) {
      announceForAccessibility(context, '${tipo.etiqueta} registrada');
    }
  }

  Future<void> _editarCosto(BuildContext context, CostoViaje costo) async {
    final ConductorViajeCubit cubit = context.read<ConductorViajeCubit>();
    final bool? ok = await ValorRealSheet.mostrar(
      context,
      etiqueta: costo.etiqueta,
      estimado: costo.valorEstimado,
      valorReal: costo.valorReal,
      alGuardar: (double v) =>
          cubit.confirmarValorReal(costoId: costo.id, valorReal: v),
    );
    if (ok == true && context.mounted) {
      announceForAccessibility(context, '${costo.etiqueta} guardado como real');
    }
  }

  Future<void> _agregarCosto(BuildContext context) async {
    final ConductorViajeCubit cubit = context.read<ConductorViajeCubit>();
    final bool? ok = await AgregarCostoSheet.mostrar(
      context,
      alGuardar: (String descripcion, double valor) =>
          cubit.agregarCostoLibre(descripcion: descripcion, valor: valor),
    );
    if (ok == true && context.mounted) {
      announceForAccessibility(context, 'Costo agregado como real');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConductorViajeCubit, ConductorViajeState>(
      builder: (BuildContext context, ConductorViajeState state) {
        final ConductorViajeListo? listo = state is ConductorViajeListo
            ? state
            : null;
        final TipoHito? siguiente = listo == null
            ? null
            : _siguiente(listo.hitos);
        final _PasoSalida paso = listo == null
            ? _PasoSalida.registrar
            : _pasoSalida(listo, siguiente);

        return ConductorScaffold(
          titulo: 'Inicio',
          seccionActual: ConductorSection.inicio,
          usuario: usuario,
          conAppBar: false,
          accion: listo == null
              ? null
              : _AccionPrincipal(
                  siguiente: siguiente,
                  paso: paso,
                  procesando: listo.procesando,
                  onPressed: switch (paso) {
                    _PasoSalida.hacerChecklist => () => _hacerChecklist(
                      context,
                      listo,
                    ),
                    _PasoSalida.esperarAutorizacion =>
                      () => context.read<ConductorViajeCubit>().cargar(
                        silencioso: true,
                      ),
                    _PasoSalida.registrar =>
                      siguiente == null
                          ? null
                          : () => _registrar(context, listo, siguiente),
                  },
                ),
          body: RefreshIndicator(
            onRefresh: () => context.read<ConductorViajeCubit>().cargar(),
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                _Cabecera(
                  nombre: usuario.nombre,
                  subtitulo: switch (state) {
                    ConductorViajeCargando() => 'Cargando tu viaje…',
                    ConductorViajeError() =>
                      'Lo que registraste sigue guardado',
                    ConductorViajeSinAsignar() =>
                      'Hoy no tienes viaje por hacer',
                    ConductorViajeListo() => switch (paso) {
                      _PasoSalida.hacerChecklist =>
                        'Antes de salir, revisa el vehículo',
                      _PasoSalida.esperarAutorizacion =>
                        'Falta la autorización del administrador',
                      _PasoSalida.registrar => _subtitulo(
                        listo!.viaje,
                        siguiente,
                      ),
                    },
                  },
                ),
                Stack(
                  children: <Widget>[
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(AppRadius.xl),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        0,
                        AppSpacing.x4,
                        AppSpacing.x4,
                      ),
                      child: switch (state) {
                        ConductorViajeCargando() => const _InicioSkeleton(),
                        ConductorViajeError(:final mensaje) => AppCard(
                          child: ErrorState(
                            mensaje: mensaje,
                            destacado: true,
                            onReintentar: () =>
                                context.read<ConductorViajeCubit>().cargar(),
                          ),
                        ),
                        ConductorViajeSinAsignar() => _LiberarMonitor(
                          child: const _SinViaje(),
                        ),
                        ConductorViajeListo() => _ViajeActivo(
                          estado: listo!,
                          alEditarCosto: (CostoViaje c) =>
                              _editarCosto(context, c),
                          alAgregarCosto: () => _agregarCosto(context),
                        ),
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _subtitulo(ViajeResumen viaje, TipoHito? siguiente) {
    if (siguiente == null) return 'Registraste todos los pasos. Gracias.';
    return switch (siguiente) {
      TipoHito.salida => 'Siguiente: registrar tu salida',
      TipoHito.llegadaCargue => 'Siguiente: llegada al cargue',
      TipoHito.salidaConCarga => 'Siguiente: salir con carga',
      TipoHito.llegadaDestino => 'Vas rumbo a ${viaje.destino}',
    };
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.nombre, required this.subtitulo});

  final String nombre;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final String primerNombre = nombre.trim().split(' ').first;

    return Container(
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        MediaQuery.paddingOf(context).top + AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const BrandMark(size: 32),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'OptiRuta',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.onNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Semantics(
            header: true,
            child: Text(
              'Hola, $primerNombre',
              style: AppTypography.display.copyWith(color: AppColors.onNavy),
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            subtitulo,
            style: AppTypography.body.copyWith(
              color: AppColors.onNavy.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que hace el botón principal mientras el viaje está por salir.
enum _PasoSalida { hacerChecklist, esperarAutorizacion, registrar }

class _AccionPrincipal extends StatelessWidget {
  const _AccionPrincipal({
    required this.siguiente,
    required this.paso,
    required this.procesando,
    required this.onPressed,
  });

  final TipoHito? siguiente;
  final _PasoSalida paso;
  final bool procesando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final TipoHito? t = siguiente;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: procesando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          foregroundColor: AppColors.onPrimary,
          disabledForegroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.efectiva(context, AppMotion.base),
          child: Row(
            key: ValueKey<(TipoHito?, _PasoSalida)>((t, paso)),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (paso == _PasoSalida.registrar)
                MarcaIcon(
                  t == null ? MarcaIconos.datoReal : HitoTimeline.iconoDe(t),
                  size: 22,
                  color: AppColors.onPrimary,
                )
              else
                Icon(
                  paso == _PasoSalida.hacerChecklist
                      ? LucideIcons.clipboardCheck
                      : LucideIcons.refreshCw,
                  size: 22,
                  color: AppColors.onPrimary,
                ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(switch (paso) {
                  _PasoSalida.hacerChecklist => 'Hacer checklist del vehículo',
                  _PasoSalida.esperarAutorizacion =>
                    'Revisar si ya me autorizaron',
                  _PasoSalida.registrar =>
                    t == null
                        ? 'Todos los pasos registrados'
                        : 'Registrar ${t.etiqueta.toLowerCase()}',
                }, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViajeActivo extends StatelessWidget {
  const _ViajeActivo({
    required this.estado,
    required this.alEditarCosto,
    required this.alAgregarCosto,
  });

  final ConductorViajeListo estado;
  final void Function(CostoViaje costo) alEditarCosto;
  final VoidCallback alAgregarCosto;

  /// Estado del checklist antes de salir: bloqueado o listo. Sin checklist no
  /// se muestra nada (el botón ya lo pide).
  Widget? get _avisoChecklist {
    final ChecklistViaje? c = estado.checklist;
    if (c == null ||
        estado.viaje.estado != EstadoViaje.asignado ||
        c.estaVencido(DateTime.now())) {
      return null;
    }
    if (c.bloqueaSalida) {
      return const AppAlert(
        tono: AppAlertTono.advertencia,
        titulo: 'Checklist con falla crítica',
        mensaje:
            'El administrador ya fue avisado. Podrás comenzar el viaje cuando '
            'autorice la salida.',
      );
    }
    return AppAlert(
      tono: c.resultado == ResultadoChecklist.aprobado
          ? AppAlertTono.exito
          : AppAlertTono.advertencia,
      titulo: c.autorizado
          ? 'Salida autorizada'
          : 'Checklist ${c.resultado.etiqueta.toLowerCase()}',
      mensaje: c.autorizado
          ? 'El administrador autorizó la salida. Ya puedes comenzar.'
          : 'Listo para comenzar el viaje.',
    );
  }

  DateTime? get _estimadoDestino {
    final double? min = estado.viaje.tiempoEstimadoMin;
    if (min == null) return null;
    for (final Hito h in estado.hitos) {
      if (h.tipo == TipoHito.salida) {
        return h.fechaHora.add(Duration(minutes: min.round()));
      }
    }
    return null;
  }

  static String _duracion(double minutos) {
    final int total = minutos.round();
    final int h = total ~/ 60;
    final int m = total % 60;
    return h == 0 ? '$m min' : '$h h ${m.toString().padLeft(2, '0')} min';
  }

  @override
  Widget build(BuildContext context) {
    final ViajeResumen viaje = estado.viaje;
    final List<String> estimados = <String>[
      if (viaje.distanciaEstimada != null)
        '${viaje.distanciaEstimada!.round()} km',
      if (viaje.tiempoEstimadoMin != null) _duracion(viaje.tiempoEstimadoMin!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_avisoChecklist != null) ...<Widget>[
          _avisoChecklist!,
          const SizedBox(height: AppSpacing.x3),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      'Viaje ${viaje.remision}',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  EstadoViajeBadge(estado: viaje.estado),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              MapaRutaViaje(
                viaje: viaje,
                monitorear: viaje.estado == EstadoViaje.enCurso,
              ),
              const SizedBox(height: AppSpacing.x1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(viaje.origen, style: AppTypography.subtitle),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      viaje.destino,
                      style: AppTypography.subtitle,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (estimados.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.x3),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.x3),
                Row(
                  children: <Widget>[
                    const MarcaIcon(
                      MarcaIconos.datoEstimado,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x1),
                    Expanded(
                      child: Text(
                        'Ruta estimada · ${estimados.join(' · ')}',
                        style: AppTypography.caption.copyWith(
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.x3),
              Row(
                children: <Widget>[
                  if (viaje.tipoVehiculo != null) ...<Widget>[
                    VehiculoThumb(tipo: viaje.tipoVehiculo!),
                    const SizedBox(width: AppSpacing.x3),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          viaje.tipoVehiculo == null
                              ? viaje.placaVehiculo
                              : '${viaje.placaVehiculo} · '
                                    '${viaje.tipoVehiculo!.etiqueta}',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Cliente · ${viaje.nombreCliente}',
                          style: AppTypography.caption,
                        ),
                        if (viaje.pesoCarga != null)
                          Text(
                            'Carga · ${viaje.pesoCarga!.round()} t',
                            style: AppTypography.caption,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Avance del viaje', style: AppTypography.subtitle),
              const SizedBox(height: AppSpacing.x2),
              HitoTimeline(
                hitos: estado.hitos,
                estimadoDestino: _estimadoDestino,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        CostosViajeCard(
          costos: estado.costos,
          deshabilitado: estado.procesando,
          alEditar: alEditarCosto,
          alAgregar: estado.viaje.estado == EstadoViaje.asignado
              ? null
              : alAgregarCosto,
        ),
      ],
    );
  }
}

class _SinViaje extends StatelessWidget {
  const _SinViaje();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
        child: Column(
          children: <Widget>[
            const IlustracionEstadoView(IlustracionEstado.sinViaje),
            const SizedBox(height: AppSpacing.x2),
            const Text(
              'Hoy no tienes viaje asignado',
              style: AppTypography.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Cuando te asignen uno, aparecerá aquí con todo lo que '
              'necesitas para salir.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            SecondaryButton(
              label: 'Ver mis viajes anteriores',
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.conductorHistorial),
            ),
          ],
        ),
      ),
    );
  }
}

class _InicioSkeleton extends StatelessWidget {
  const _InicioSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonBlock(alto: 14, ancho: 120),
              SizedBox(height: AppSpacing.x3),
              SkeletonBlock(alto: 56),
              SizedBox(height: AppSpacing.x3),
              SkeletonBlock(alto: 54, ancho: 200),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.x3),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonBlock(alto: 16, ancho: 140),
              SizedBox(height: AppSpacing.x3),
              SkeletonBlock(alto: 36),
              SizedBox(height: AppSpacing.x3),
              SkeletonBlock(alto: 36),
              SizedBox(height: AppSpacing.x3),
              SkeletonBlock(alto: 36),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sin viaje activo (terminó o no hay) se detiene el seguimiento y su
/// servicio en primer plano.
class _LiberarMonitor extends StatefulWidget {
  const _LiberarMonitor({required this.child});

  final Widget child;

  @override
  State<_LiberarMonitor> createState() => _LiberarMonitorState();
}

class _LiberarMonitorState extends State<_LiberarMonitor> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MonitorRutaRegistro>().liberar();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
