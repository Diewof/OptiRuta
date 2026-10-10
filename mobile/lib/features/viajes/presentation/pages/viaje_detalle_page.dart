import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/accessibility/announce.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/cifra_animada.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/estado_viaje_badge.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../../../core/widgets/primary_action_button.dart';
import '../../../../core/widgets/semaforo_badge.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/vehiculo_thumb.dart';
import '../../domain/entities/ajuste_viaje.dart';
import '../../domain/entities/categoria_costo.dart';
import '../../domain/entities/coordenada.dart';
import '../../domain/entities/costo_viaje.dart';
import '../../domain/entities/estado_viaje.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';
import '../../domain/entities/viaje_resumen.dart';
import '../../domain/repositories/ajuste_viaje_repository.dart';
import '../../domain/repositories/costo_viaje_repository.dart';
import '../../domain/repositories/hito_repository.dart';
import '../../domain/repositories/rentabilidad_repository.dart';
import '../../domain/repositories/viaje_repository.dart';
import '../../domain/usecases/cerrar_viaje_use_case.dart';
import '../../domain/usecases/listar_ajustes_viaje_use_case.dart';
import '../../domain/usecases/listar_costos_viaje_use_case.dart';
import '../../domain/usecases/listar_hitos_use_case.dart';
import '../../domain/usecases/registrar_ajuste_viaje_use_case.dart';
import '../../domain/usecases/rentabilidad_marginal_use_case.dart';
import '../bloc/viaje_detalle_cubit.dart';
import '../bloc/viaje_detalle_state.dart';
import '../widgets/cerrar_viaje_sheets.dart';
import '../widgets/mapa_ruta_viaje.dart';
import '../widgets/estimado_real_tabla.dart';
import '../widgets/hito_timeline.dart';

/// Detalle de un viaje con su rentabilidad **marginal** (flete pactado menos
/// costos directos; el mantenimiento amortizado y el sueldo fijo no entran
/// aquí, solo en la consolidada del Resumen), el estimado vs. real, los tiempos
/// de los hitos y, para el administrador, el cierre y los ajustes con motivo.
///
/// El estado del semáforo lo calculará el servidor cuando se definan los
/// umbrales; hasta entonces no se muestra (no se inventa una regla en la app).
class ViajeDetallePage extends StatelessWidget {
  const ViajeDetallePage({
    required this.viaje,
    this.puedeCerrar = false,
    this.alerta,
    super.key,
  });

  final ViajeResumen viaje;

  /// Dónde el teléfono del conductor detectó una parada o un desvío; se marca
  /// en el mapa cuando se llega desde una notificación de alerta.
  final Coordenada? alerta;

  /// Solo el administrador cierra viajes y registra ajustes (RPC + RLS lo
  /// hacen cumplir; esto solo evita ofrecer la acción a quien no puede).
  final bool puedeCerrar;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ViajeDetalleCubit>(
      create: (BuildContext context) => ViajeDetalleCubit(
        viaje: viaje,
        listarHitos: ListarHitosUseCase(context.read<HitoRepository>()),
        listarCostos: ListarCostosViajeUseCase(
          context.read<CostoViajeRepository>(),
        ),
        rentabilidadMarginal: RentabilidadMarginalUseCase(
          context.read<RentabilidadRepository>(),
        ),
        listarAjustes: ListarAjustesViajeUseCase(
          context.read<AjusteViajeRepository>(),
        ),
        cerrarViaje: CerrarViajeUseCase(context.read<ViajeRepository>()),
        registrarAjuste: RegistrarAjusteViajeUseCase(
          context.read<AjusteViajeRepository>(),
        ),
      ),
      child: _Vista(viaje: viaje, puedeCerrar: puedeCerrar, alerta: alerta),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({required this.viaje, required this.puedeCerrar, this.alerta});

  final ViajeResumen viaje;
  final bool puedeCerrar;
  final Coordenada? alerta;

  static List<CostoViaje> _costosDelViaje(List<CostoViaje> costos) {
    final List<CostoViaje> r = costos
        .where(
          (CostoViaje c) =>
              c.categoria != CategoriaCosto.mantenimientoAmortizado,
        )
        .toList();
    int orden(CategoriaCosto c) => switch (c) {
      CategoriaCosto.acpm => 0,
      CategoriaCosto.peaje => 1,
      _ => 2,
    };
    r.sort((CostoViaje a, CostoViaje b) {
      final int o = orden(a.categoria).compareTo(orden(b.categoria));
      return o != 0 ? o : a.categoria.etiqueta.compareTo(b.categoria.etiqueta);
    });
    return r;
  }

  Future<void> _cerrar(BuildContext context, ViajeDetalleListo e) async {
    final ViajeDetalleCubit cubit = context.read<ViajeDetalleCubit>();
    final NumberFormatCop moneda = NumberFormatCop();
    final List<String> pendientes = _costosDelViaje(e.costos)
        .where((CostoViaje c) => c.valorReal == null)
        .map(
          (CostoViaje c) =>
              '${c.categoria.etiqueta.toLowerCase()} ≈ ${moneda.formatear(c.valorEstimado)}',
        )
        .toList();
    final bool? cerrado = await CerrarViajeSheet.mostrar(
      context,
      remision: viaje.remision,
      costosEstimados: pendientes,
      alConfirmar: cubit.cerrar,
    );
    if (cerrado == true && context.mounted) {
      announceForAccessibility(context, 'Viaje ${viaje.remision} cerrado');
      final ViajeDetalleState s = cubit.state;
      final double renta = s is ViajeDetalleListo
          ? s.marginal.rentabilidad
          : e.marginal.rentabilidad;
      final double flete = e.marginal.valorFlete;
      await ViajeCerradoSheet.mostrar(
        context,
        remision: viaje.remision,
        resumen:
            'Rentabilidad del viaje ${formatearMillones(renta, decimales: 2)}'
            '${flete > 0 ? ' · margen ${formatearPorcentaje(renta / flete * 100)}' : ''}. '
            'Desde ahora solo se corrige con ajustes.',
      );
    }
  }

  Future<void> _ajustar(BuildContext context, ViajeDetalleListo e) async {
    final ViajeDetalleCubit cubit = context.read<ViajeDetalleCubit>();
    final NumberFormatCop moneda = NumberFormatCop();
    final ok = await AjusteViajeSheet.mostrar(
      context,
      conceptos: <ConceptoAjustable>[
        for (final CostoViaje c in _costosDelViaje(e.costos))
          ConceptoAjustable(
            etiqueta: c.categoria.etiqueta,
            valorActual: moneda.formatear(c.valorReal ?? c.valorEstimado),
          ),
      ],
      alGuardar:
          ({
            required String motivo,
            required String campo,
            required String valorAnterior,
            required String valorNuevo,
          }) => cubit.registrarAjuste(
            motivo: motivo,
            campoModificado: campo,
            valorAnterior: valorAnterior,
            valorNuevo: valorNuevo,
          ),
    );
    if (ok == true && context.mounted) {
      announceForAccessibility(context, 'Ajuste registrado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViajeDetalleCubit, ViajeDetalleState>(
      builder: (BuildContext context, ViajeDetalleState state) {
        final ViajeDetalleListo? listo = state is ViajeDetalleListo
            ? state
            : null;
        final bool mostrarAccion =
            puedeCerrar &&
            listo != null &&
            (listo.estado == EstadoViaje.finalizado ||
                listo.estado == EstadoViaje.cerrado);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            foregroundColor: AppColors.onNavy,
            title: Text(
              'Viaje ${viaje.remision}',
              style: AppTypography.subtitle.copyWith(color: AppColors.onNavy),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: ColoredBox(
                color: AppColors.brandRed,
                child: SizedBox(height: 2, width: double.infinity),
              ),
            ),
          ),
          bottomNavigationBar: mostrarAccion
              ? _BarraAccion(
                  cerrado: listo.estado == EstadoViaje.cerrado,
                  procesando: listo.procesando,
                  onCerrar: () => _cerrar(context, listo),
                  onAjustar: () => _ajustar(context, listo),
                )
              : null,
          body: switch (state) {
            ViajeDetalleCargando() => const _Esqueleto(),
            ViajeDetalleError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () =>
                      context.read<ViajeDetalleCubit>().cargar(),
                ),
              ],
            ),
            ViajeDetalleListo() => _Contenido(
              estado: state,
              costos: _costosDelViaje(state.costos),
              alerta: alerta,
            ),
          },
        );
      },
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
          SkeletonBlock(alto: 180, radio: 16),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 140, radio: 16),
          SizedBox(height: AppSpacing.x3),
          SkeletonBlock(alto: 220, radio: 16),
        ],
      ),
    );
  }
}

class _BarraAccion extends StatelessWidget {
  const _BarraAccion({
    required this.cerrado,
    required this.procesando,
    required this.onCerrar,
    required this.onAjustar,
  });

  final bool cerrado;
  final bool procesando;
  final VoidCallback onCerrar;
  final VoidCallback onAjustar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.dividerTable)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                cerrado
                    ? 'Este viaje ya no se edita. Cualquier corrección es un ajuste con motivo.'
                    : 'Al cerrar el viaje, los cambios solo se harán como ajustes con motivo.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.x2),
              PrimaryActionButton(
                label: cerrado ? 'Registrar ajuste' : 'Cerrar viaje',
                leadingIcon: cerrado ? LucideIcons.history : LucideIcons.lock,
                grande: true,
                onPressed: procesando ? null : (cerrado ? onAjustar : onCerrar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado, required this.costos, this.alerta});

  final ViajeDetalleListo estado;
  final List<CostoViaje> costos;
  final Coordenada? alerta;

  BaseCalculo get _base {
    if (costos.isEmpty) return BaseCalculo.proyectada;
    final int reales = costos
        .where((CostoViaje c) => c.valorReal != null)
        .length;
    if (estado.ajustes.isNotEmpty && estado.estado == EstadoViaje.cerrado) {
      return BaseCalculo.ajustada;
    }
    if (reales == costos.length) return BaseCalculo.confirmada;
    if (reales == 0) return BaseCalculo.proyectada;
    return BaseCalculo.parcial;
  }

  @override
  Widget build(BuildContext context) {
    final double flete = estado.marginal.valorFlete;
    final double renta = estado.marginal.rentabilidad;
    final double estCostos = costos.fold<double>(
      0,
      (double a, CostoViaje c) => a + c.valorEstimado,
    );
    final double margenEst = flete - estCostos;
    final List<CostoViaje> sinReal = costos
        .where((CostoViaje c) => c.valorReal == null)
        .toList();

    return RefreshIndicator(
      onRefresh: () =>
          context.read<ViajeDetalleCubit>().cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          _Resumen(estado: estado, alerta: alerta),
          const SizedBox(height: AppSpacing.x3),
          Semantics(
            container: true,
            label:
                'Rentabilidad marginal del viaje: ${formatearMillones(renta, decimales: 2)}',
            child: ExcludeSemantics(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x1,
                      children: <Widget>[
                        Text(
                          'Rentabilidad del viaje · marginal',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        BaseCalculoChip(base: _base),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: AppSpacing.x3,
                      children: <Widget>[
                        CifraAnimada(
                          valor: renta,
                          formato: (double x) =>
                              formatearMillones(x, decimales: 2),
                          estilo: AppTypography.hero,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            const Text(
                              'Estimado inicial',
                              style: AppTypography.caption,
                            ),
                            Text(
                              '≈ ${formatearMillones(margenEst, decimales: 2)}',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (flete > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        'Margen ${formatearPorcentaje(renta / flete * 100)}',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      sinReal.isEmpty
                          ? 'Todos los costos están confirmados.'
                          : '${sinReal.length == 1 ? 'Falta 1 costo real' : 'Faltan ${sinReal.length} costos reales'}: '
                                '${sinReal.map((CostoViaje c) => c.categoria.etiqueta.toLowerCase()).join(', ')}. '
                                'Mientras tanto se usa el estimado.',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Estimado vs. real',
                        style: AppTypography.subtitle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text('Miles de COP', style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                EstimadoRealTabla(
                  flete: flete,
                  filas: <FilaEstimadoReal>[
                    for (final CostoViaje c in costos)
                      FilaEstimadoReal(
                        concepto: c.categoria.etiqueta,
                        fuente: c.categoria == CategoriaCosto.peaje
                            ? (c.valorReal == null
                                  ? 'GoPass · esperando'
                                  : 'GoPass')
                            : c.fuente.etiqueta,
                        estimado: c.valorEstimado,
                        real: c.valorReal,
                      ),
                  ],
                  margenEstimado: margenEst,
                  margenActual: renta,
                  margenConfirmado: sinReal.isEmpty,
                ),
                const SizedBox(height: AppSpacing.x3),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.x3),
                const _Leyenda(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          const AppCard(
            stripe: AppCardStripe.left,
            stripeColor: AppColors.primary,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MarcaIcon(MarcaIconos.info, size: 20, color: AppColors.primary),
                SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Esto es la rentabilidad del viaje',
                        style: AppTypography.label,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'El mantenimiento amortizado y el sueldo fijo no entran '
                        'aquí: se cuentan en la rentabilidad consolidada del '
                        'período (Resumen).',
                        style: AppTypography.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          _Tiempos(estado: estado),
          if (estado.ajustes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            _Ajustes(ajustes: estado.ajustes),
          ],
          const SizedBox(height: AppSpacing.x4),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    Widget item(MarcaIconos i, String t, Color c) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MarcaIcon(i, size: 14, color: c),
        const SizedBox(width: 4),
        Text(t, style: AppTypography.caption),
      ],
    );
    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x1,
      children: <Widget>[
        item(MarcaIconos.datoEstimado, 'Estimado', AppColors.textSecondary),
        item(MarcaIconos.check, 'Real', AppColors.success),
        item(MarcaIconos.datoParcial, 'Parcial', AppColors.textSecondary),
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.estado, this.alerta});

  final ViajeDetalleListo estado;
  final Coordenada? alerta;

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

  @override
  Widget build(BuildContext context) {
    final ViajeResumen v = estado.viaje;
    final DateTime? est = _estimadoDestino;
    Hito? llegada;
    for (final Hito h in estado.hitos) {
      if (h.tipo == TipoHito.llegadaDestino) llegada = h;
    }
    final int? delta = (est != null && llegada != null)
        ? llegada.fechaHora.difference(est).inMinutes
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.x2,
            children: <Widget>[
              EstadoViajeBadge(estado: estado.estado),
              Text(
                v.nombreCliente,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text('${v.origen} → ${v.destino}', style: AppTypography.title),
          const SizedBox(height: AppSpacing.x2),
          MapaRutaViaje(viaje: v, alerta: alerta),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: <Widget>[
              if (v.tipoVehiculo != null) ...<Widget>[
                VehiculoThumb(tipo: v.tipoVehiculo!),
                const SizedBox(width: AppSpacing.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      v.tipoVehiculo == null
                          ? v.placaVehiculo
                          : '${v.placaVehiculo} · ${v.tipoVehiculo!.etiqueta}',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${v.nombreConductor}'
                      '${v.distanciaEstimada != null ? ' · ≈ ${v.distanciaEstimada!.round()} km' : ''}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (delta != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x3),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.x3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MarcaIcon(
                  MarcaIconos.retraso,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    delta == 0
                        ? 'Llegó a la hora estimada'
                        : 'Llegó ${delta.abs()} min ${delta > 0 ? 'después' : 'antes'} de lo estimado',
                    style: AppTypography.label,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tiempos extends StatelessWidget {
  const _Tiempos({required this.estado});

  final ViajeDetalleListo estado;

  @override
  Widget build(BuildContext context) {
    final double? min = estado.viaje.tiempoEstimadoMin;
    Hito? hitoDe(TipoHito t) {
      for (final Hito h in estado.hitos) {
        if (h.tipo == t) return h;
      }
      return null;
    }

    final Hito? salida = hitoDe(TipoHito.salida);
    final DateTime? estDestino = (min != null && salida != null)
        ? salida.fechaHora.add(Duration(minutes: min.round()))
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Tiempos del viaje', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x2),
          for (final TipoHito t in HitoTimeline.orden)
            Builder(
              builder: (BuildContext context) {
                final Hito? h = hitoDe(t);
                final DateTime? est = t == TipoHito.llegadaDestino
                    ? estDestino
                    : null;
                final int? d = (h != null && est != null)
                    ? h.fechaHora.difference(est).inMinutes
                    : null;
                return Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                  decoration: BoxDecoration(
                    border: t == TipoHito.llegadaDestino
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.dividerTable),
                          ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.navyTint,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        alignment: Alignment.center,
                        child: MarcaIcon(
                          HitoTimeline.iconoDe(t),
                          size: 22,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Text(
                          t.etiqueta,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            h == null
                                ? 'Pendiente'
                                : formatearHora(h.fechaHora),
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: h == null
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontFeatures: AppTypography.tabular,
                            ),
                          ),
                          if (est != null)
                            Text(
                              'Est. ${formatearHora(est)}'
                              '${d != null ? ' · ${d == 0 ? 'a la hora' : '${d > 0 ? '+' : '−'}${d.abs()} min'}' : ''}',
                              style: AppTypography.caption.copyWith(
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Ajustes extends StatelessWidget {
  const _Ajustes({required this.ajustes});

  final List<AjusteViaje> ajustes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              MarcaIcon(
                MarcaIconos.datoAjustado,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  'Ajustes registrados',
                  style: AppTypography.subtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          for (int i = 0; i < ajustes.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
              decoration: BoxDecoration(
                border: i == ajustes.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.dividerTable),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    <String>[
                      if (ajustes[i].campoModificado != null)
                        ajustes[i].campoModificado!,
                      if (ajustes[i].valorAnterior != null &&
                          ajustes[i].valorNuevo != null)
                        '${ajustes[i].valorAnterior} → ${ajustes[i].valorNuevo}',
                    ].join(' · '),
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                  Text(ajustes[i].motivo, style: AppTypography.body),
                  Text(
                    formatearFechaHoraCorta(ajustes[i].fecha.toLocal()),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
