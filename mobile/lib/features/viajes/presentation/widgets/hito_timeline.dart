import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/widgets/marca_icon.dart';
import '../../domain/entities/hito.dart';
import '../../domain/entities/tipo_hito.dart';

/// «Hilo de ruta» del viaje: los 4 hitos como nodos unidos por un hilo que se
/// rellena a medida que se registran. El siguiente queda destacado. Al
/// registrar uno, el check se dibuja y el tramo se rellena; con «reducir
/// movimiento» el cambio es instantáneo.
///
/// Solo muestra una hora estimada donde el sistema puede calcularla de verdad
/// ([estimadoDestino]); en los demás hitos no inventa estimados.
class HitoTimeline extends StatelessWidget {
  const HitoTimeline({required this.hitos, this.estimadoDestino, super.key});

  final List<Hito> hitos;

  /// Hora estimada de llegada a destino (salida real + tiempo estimado).
  final DateTime? estimadoDestino;

  static const List<TipoHito> orden = <TipoHito>[
    TipoHito.salida,
    TipoHito.llegadaCargue,
    TipoHito.salidaConCarga,
    TipoHito.llegadaDestino,
  ];

  static MarcaIconos iconoDe(TipoHito t) => switch (t) {
    TipoHito.salida => MarcaIconos.hitoSalida,
    TipoHito.llegadaCargue => MarcaIconos.hitoCargue,
    TipoHito.salidaConCarga => MarcaIconos.hitoConCarga,
    TipoHito.llegadaDestino => MarcaIconos.hitoDestino,
  };

  Hito? _hitoDe(TipoHito tipo) {
    for (final Hito h in hitos) {
      if (h.tipo == tipo) return h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final int siguiente = orden.indexWhere((TipoHito t) => _hitoDe(t) == null);

    return Column(
      children: <Widget>[
        for (int i = 0; i < orden.length; i++)
          _FilaHito(
            tipo: orden[i],
            hito: _hitoDe(orden[i]),
            esSiguiente: i == siguiente,
            esUltimo: i == orden.length - 1,
            tramoRelleno: i + 1 < orden.length && _hitoDe(orden[i + 1]) != null,
            estimado: orden[i] == TipoHito.llegadaDestino
                ? estimadoDestino
                : null,
          ),
      ],
    );
  }
}

class _FilaHito extends StatelessWidget {
  const _FilaHito({
    required this.tipo,
    required this.hito,
    required this.esSiguiente,
    required this.esUltimo,
    required this.tramoRelleno,
    required this.estimado,
  });

  final TipoHito tipo;
  final Hito? hito;
  final bool esSiguiente;
  final bool esUltimo;
  final bool tramoRelleno;
  final DateTime? estimado;

  @override
  Widget build(BuildContext context) {
    final bool hecho = hito != null;
    final String lectura = hecho
        ? '${tipo.etiqueta}, registrado a las ${formatearHora(hito!.fechaHora)}'
        : esSiguiente
        ? '${tipo.etiqueta}, siguiente paso'
        : '${tipo.etiqueta}, pendiente';

    return Semantics(
      container: true,
      label: lectura,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppMotion.efectiva(context, AppMotion.base),
          curve: AppMotion.easeOut,
          margin: EdgeInsets.only(bottom: esUltimo ? 0 : 0),
          decoration: BoxDecoration(
            color: esSiguiente ? AppColors.navyTint : Colors.transparent,
            borderRadius: AppRadius.mdAll,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x2,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 32,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      // El hilo baja hasta el borde de la fila y cruza el
                      // espacio hasta el nodo siguiente.
                      if (!esUltimo)
                        Positioned(
                          top: 32,
                          bottom: -AppSpacing.x4,
                          left: 15,
                          width: 2,
                          child: _Hilo(relleno: tramoRelleno),
                        ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: _NodoHito(
                          icono: HitoTimeline.iconoDe(tipo),
                          hecho: hecho,
                          siguiente: esSiguiente,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      bottom: esUltimo ? 0 : AppSpacing.x4,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.x2,
                      runSpacing: AppSpacing.x1,
                      children: <Widget>[
                        Text(
                          tipo.etiqueta,
                          style: AppTypography.body.copyWith(
                            fontWeight: esSiguiente || hecho
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: hecho || esSiguiente
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (esSiguiente)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x2,
                              vertical: 1,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppRadius.pillAll,
                            ),
                            child: Text(
                              'Siguiente',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _Hora(hito: hito, estimado: estimado),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hora extends StatelessWidget {
  const _Hora({required this.hito, required this.estimado});

  final Hito? hito;
  final DateTime? estimado;

  @override
  Widget build(BuildContext context) {
    final TextStyle numero = AppTypography.body.copyWith(
      fontFeatures: AppTypography.tabular,
    );

    final Widget contenido;
    if (hito != null) {
      contenido = Column(
        key: const ValueKey<String>('real'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            formatearHora(hito!.fechaHora),
            style: numero.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Text('Real', style: AppTypography.caption),
        ],
      );
    } else if (estimado != null) {
      contenido = Column(
        key: const ValueKey<String>('estimado'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            '≈ ${formatearHora(estimado!)}',
            style: numero.copyWith(color: AppColors.textSecondary),
          ),
          const Text('Estimado', style: AppTypography.caption),
        ],
      );
    } else {
      contenido = const Text(
        'Pendiente',
        key: ValueKey<String>('pendiente'),
        style: AppTypography.caption,
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.efectiva(context, AppMotion.base),
      switchInCurve: AppMotion.easeOut,
      transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      ),
      child: contenido,
    );
  }
}

/// Tramo entre dos nodos: gris, y verde cuando el hito siguiente ya ocurrió.
class _Hilo extends StatelessWidget {
  const _Hilo({required this.relleno});

  final bool relleno;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.dividerTable),
          ),
        ),
        Positioned.fill(
          child: AnimatedFractionallySizedBox(
            duration: AppMotion.efectiva(context, AppMotion.slow),
            curve: AppMotion.easeInOut,
            alignment: Alignment.topCenter,
            widthFactor: 1,
            heightFactor: relleno ? 1 : 0,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.success),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nodo del hilo. Cuando pasa de pendiente a hecho, «salta» y dibuja el check.
class _NodoHito extends StatefulWidget {
  const _NodoHito({
    required this.icono,
    required this.hecho,
    required this.siguiente,
  });

  final MarcaIconos icono;
  final bool hecho;
  final bool siguiente;

  @override
  State<_NodoHito> createState() => _NodoHitoState();
}

class _NodoHitoState extends State<_NodoHito>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
    value: widget.hecho ? 1 : 0,
  );

  @override
  void didUpdateWidget(_NodoHito old) {
    super.didUpdateWidget(old);
    if (widget.hecho && !old.hecho) {
      if (AppMotion.reducir(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    } else if (!widget.hecho && old.hecho) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hecho = widget.hecho;
    final Color borde = hecho
        ? AppColors.success
        : widget.siguiente
        ? AppColors.primary
        : AppColors.borderInput;

    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) {
        // Salto breve (0,8 → 1,08 → 1) solo mientras se anima el cambio.
        final double t = _c.value;
        final double escala = (_c.isAnimating)
            ? (t < 0.6
                  ? 0.8 + 0.28 * (t / 0.6)
                  : 1.08 - 0.08 * ((t - 0.6) / 0.4))
            : 1;
        return Transform.scale(
          scale: escala,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hecho ? AppColors.success : AppColors.card,
              border: Border.all(color: borde, width: 2),
            ),
            alignment: Alignment.center,
            child: hecho
                ? CustomPaint(
                    size: const Size(18, 18),
                    painter: _CheckPainter(progreso: _c.value),
                  )
                : MarcaIcon(
                    widget.icono,
                    size: 18,
                    color: widget.siguiente
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progreso});

  final double progreso;

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 24;
    final Path check = Path()
      ..moveTo(5 * k, 12.5 * k)
      ..lineTo(9.5 * k, 17 * k)
      ..lineTo(19 * k, 7.5 * k);
    final Path parcial = Path();
    for (final metrica in check.computeMetrics()) {
      parcial.addPath(
        metrica.extractPath(0, metrica.length * progreso.clamp(0, 1)),
        Offset.zero,
      );
    }
    canvas.drawPath(
      parcial,
      Paint()
        ..color = AppColors.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progreso != progreso;
}
