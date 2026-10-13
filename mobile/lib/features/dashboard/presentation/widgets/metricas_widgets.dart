import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/chip_opcion.dart';
import '../../../notificaciones/domain/entities/notificacion.dart';
import '../../../notificaciones/presentation/widgets/tipo_notificacion_visual.dart';
import '../../domain/entities/metricas.dart';

/// Notificaciones sin leer del mes que se está viendo (RF-26): avisos,
/// críticas, viajes completados e información, con acceso a la bandeja
/// completa. No se muestra si no hay ninguna.
///
/// La franja y el icono de cabecera son azul marino y de campana: lo que llega
/// aquí no es solo advertencia. El color de cada tipo vive en su propio icono.
class AlertasActivasCard extends StatelessWidget {
  const AlertasActivasCard({required this.alertas, super.key});

  final List<Notificacion> alertas;

  static const int _maximo = 3;

  /// Cuántas hay de cada naturaleza, para que se vea de un vistazo que no son
  /// todas advertencias.
  static const List<(Color, IconData, String, String)> _categorias =
      <(Color, IconData, String, String)>[
        (AppColors.error, LucideIcons.circleAlert, 'crítica', 'críticas'),
        (AppColors.warning, LucideIcons.triangleAlert, 'aviso', 'avisos'),
        (
          AppColors.success,
          LucideIcons.circleCheck,
          'completado',
          'completados',
        ),
        (AppColors.navy, LucideIcons.info, 'informativa', 'informativas'),
      ];

  @override
  Widget build(BuildContext context) {
    if (alertas.isEmpty) return const SizedBox.shrink();

    return AppCard(
      stripe: AppCardStripe.left,
      stripeColor: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(LucideIcons.bell, size: 18, color: AppColors.navy),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  alertas.length == 1
                      ? '1 alerta activa'
                      : '${alertas.length} alertas activas',
                  style: AppTypography.subtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x1,
            children: <Widget>[
              for (final (
                    Color color,
                    IconData icono,
                    String singular,
                    String plural,
                  )
                  in _categorias)
                if (_cuantas(color) > 0)
                  _Conteo(
                    color: color,
                    icono: icono,
                    texto:
                        '${_cuantas(color)} '
                        '${_cuantas(color) == 1 ? singular : plural}',
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          for (final Notificacion n in alertas.take(_maximo)) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(n.tipo.icono, size: 18, color: n.tipo.color),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        n.titulo,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(n.mensaje, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.adminNotificaciones),
              child: const Text('Ver todas las notificaciones'),
            ),
          ),
        ],
      ),
    );
  }

  int _cuantas(Color color) =>
      alertas.where((Notificacion n) => n.tipo.color == color).length;
}

class _Conteo extends StatelessWidget {
  const _Conteo({
    required this.color,
    required this.icono,
    required this.texto,
  });

  final Color color;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icono, size: 14, color: color),
        const SizedBox(width: AppSpacing.x1),
        Text(
          texto,
          style: AppTypography.caption.copyWith(
            fontFeatures: AppTypography.tabular,
          ),
        ),
      ],
    );
  }
}

/// Costo por km, cumplimiento de tiempos y utilización de flota del período
/// (RF-24/25). Si falta la base de cálculo se dice «Sin datos», no se inventa.
class MetricasOperativas extends StatelessWidget {
  const MetricasOperativas({required this.metricas, super.key});

  final MetricasPeriodo metricas;

  @override
  Widget build(BuildContext context) {
    final NumberFormatCop moneda = NumberFormatCop();
    final double? cumplimiento = metricas.cumplimientoPct;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Indicadores del período', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Km estimados por la ruta, sobre viajes cerrados.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Indicador(
                etiqueta: 'Costo por km',
                valor: metricas.costoPorKm == null
                    ? 'Sin datos'
                    : moneda.formatear(metricas.costoPorKm!),
              ),
              _Indicador(
                etiqueta: 'Cumplimiento',
                valor: cumplimiento == null
                    ? 'Sin datos'
                    : formatearPorcentaje(cumplimiento),
              ),
              _Indicador(
                etiqueta: 'Uso de flota',
                valor: formatearPorcentaje(metricas.utilizacionFlotaPct),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

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
        ],
      ),
    );
  }
}

/// Rendimiento por ruta, cliente o conductor (RF-25), ordenado por
/// rentabilidad.
class RendimientoCard extends StatefulWidget {
  const RendimientoCard({required this.rendimiento, super.key});

  final Map<DimensionMetrica, List<MetricaDimension>> rendimiento;

  @override
  State<RendimientoCard> createState() => _RendimientoCardState();
}

class _RendimientoCardState extends State<RendimientoCard> {
  DimensionMetrica _dimension = DimensionMetrica.ruta;

  @override
  Widget build(BuildContext context) {
    final List<MetricaDimension> filas =
        widget.rendimiento[_dimension] ?? const <MetricaDimension>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Rendimiento', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: <Widget>[
              for (final DimensionMetrica d in DimensionMetrica.values)
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
            for (final MetricaDimension f in filas) _FilaRendimiento(fila: f),
        ],
      ),
    );
  }
}

class _FilaRendimiento extends StatelessWidget {
  const _FilaRendimiento({required this.fila});

  final MetricaDimension fila;

  @override
  Widget build(BuildContext context) {
    final double? cumplimiento = fila.cumplimientoPct;
    final String viajes = fila.viajes == 1
        ? '1 viaje'
        : '${fila.viajes} viajes';

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
                  '$viajes · ${cumplimiento == null ? 'sin medición de tiempos' : 'a tiempo ${formatearPorcentaje(cumplimiento)}'}',
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
