import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/admin_scaffold.dart';
import '../../../../core/widgets/admin_section.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/selector_mes.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../autenticacion/domain/entities/usuario.dart';
import '../../domain/entities/espera_cliente.dart';
import '../../domain/repositories/espera_repository.dart';
import '../../domain/usecases/obtener_esperas_use_case.dart';
import '../bloc/esperas_cubit.dart';
import '../bloc/esperas_state.dart';

/// Tiempos muertos en cargue y descargue (pestaña del Resumen): horas de
/// espera promedio por cliente, con las esperas largas marcadas. El sistema
/// solo informa y alerta; el cobro de standby se negocia fuera de la app.
class EsperasPage extends StatelessWidget {
  const EsperasPage({required this.usuario, super.key});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EsperasCubit>(
      create: (BuildContext context) => EsperasCubit(
        obtener: ObtenerEsperasPorClienteUseCase(
          context.read<EsperaRepository>(),
        ),
      ),
      child: _EsperasView(usuario: usuario),
    );
  }
}

class _EsperasView extends StatelessWidget {
  const _EsperasView({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      titulo: 'Resumen',
      seccionActual: AdminSection.esperas,
      usuario: usuario,
      body: BlocBuilder<EsperasCubit, EsperasState>(
        builder: (BuildContext context, EsperasState state) {
          return switch (state) {
            EsperasCargando() => const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: Column(
                children: <Widget>[
                  SkeletonBlock(alto: 48),
                  SizedBox(height: AppSpacing.x3),
                  SkeletonBlock(alto: 140, radio: 16),
                  SizedBox(height: AppSpacing.x3),
                  SkeletonBlock(alto: 140, radio: 16),
                ],
              ),
            ),
            EsperasError(:final mensaje) => ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: <Widget>[
                ErrorState(
                  mensaje: mensaje,
                  destacado: true,
                  onReintentar: () => context.read<EsperasCubit>().recargar(),
                ),
              ],
            ),
            EsperasListo() => _Contenido(estado: state),
          };
        },
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.estado});

  final EsperasListo estado;

  @override
  Widget build(BuildContext context) {
    final EsperasCubit cubit = context.read<EsperasCubit>();

    return RefreshIndicator(
      onRefresh: cubit.recargar,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          SelectorMes(
            mes: estado.mes,
            onAnterior: cubit.irAMesAnterior,
            onSiguiente: cubit.irAMesSiguiente,
          ),
          const SizedBox(height: AppSpacing.x2),
          if (estado.clientes.isEmpty)
            const EmptyState(
              icono: LucideIcons.clock,
              titulo: 'Sin esperas medidas',
              mensaje:
                  'No hay viajes finalizados en este mes. Las esperas se '
                  'miden con los hitos que registra el conductor.',
            )
          else
            for (final EsperaCliente c in estado.clientes) ...<Widget>[
              _TarjetaCliente(espera: c),
              const SizedBox(height: AppSpacing.x3),
            ],
          const _Criterios(),
        ],
      ),
    );
  }
}

class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({required this.espera});

  final EsperaCliente espera;

  static String _horas(double? h) =>
      h == null ? 'Sin medir' : '${formatearDecimal(h)} h';

  @override
  Widget build(BuildContext context) {
    final String viajes = espera.viajes == 1
        ? '1 viaje'
        : '${espera.viajes} viajes';

    return AppCard(
      stripe: espera.viajesSobreUmbral > 0
          ? AppCardStripe.left
          : AppCardStripe.none,
      stripeColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(espera.cliente, style: AppTypography.subtitle),
              ),
              Text(viajes, style: AppTypography.caption),
            ],
          ),
          if (espera.viajesSobreUmbral > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            StatusBadge(
              label: espera.viajesSobreUmbral == 1
                  ? '1 viaje con espera larga'
                  : '${espera.viajesSobreUmbral} viajes con espera larga',
              tone: StatusTone.warning,
            ),
          ],
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: _Dato(
                  etiqueta: 'Espera en cargue',
                  valor: _horas(espera.esperaCargueH),
                  nota: '${espera.carguesMedidos} medidos',
                ),
              ),
              Expanded(
                child: _Dato(
                  etiqueta: 'Espera en descargue',
                  valor: _horas(espera.esperaDescargueH),
                  nota: '${espera.descarguesMedidos} medidos',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: _Dato(
                  etiqueta: 'Total acumulado',
                  valor: '${formatearDecimal(espera.esperaTotalH)} h',
                ),
              ),
              Expanded(
                child: _Dato(
                  etiqueta: 'Espera más larga',
                  valor: '${formatearDecimal(espera.esperaMaximaH)} h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor, this.nota});

  final String etiqueta;
  final String valor;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        if (nota != null) Text(nota!, style: AppTypography.caption),
      ],
    );
  }
}

class _Criterios extends StatelessWidget {
  const _Criterios();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Cargue: de la llegada al cargue a la salida con carga. Descargue: de la '
      'llegada a destino a la salida del descargue. Solo cuentan esperas con '
      'ambos hitos registrados por el conductor. La espera larga supera 3 h '
      'y avisa al administrador; el cobro de standby se gestiona fuera de la '
      'app.',
      style: AppTypography.caption,
    );
  }
}
