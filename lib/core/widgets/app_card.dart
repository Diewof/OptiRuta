import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Lado de la franja de acento de un [AppCard].
enum AppCardStripe { none, left, top }

/// Tarjeta base del sistema de diseño: fondo blanco, borde fino, sombra
/// `AppElevation.card`, `radius.lg`, con franja lateral o superior de estado
/// opcional (sistema-de-diseno.md §5, "Tarjetas"). Usada para dashboard,
/// viajes, vehículos, conductores y resúmenes.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.stripe = AppCardStripe.none,
    this.stripeColor,
    this.padding = const EdgeInsets.all(AppSpacing.x4),
    super.key,
  });

  final Widget child;
  final AppCardStripe stripe;

  /// Color de la franja. Requerido cuando [stripe] no es [AppCardStripe.none].
  final Color? stripeColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Un `Border` con colores no uniformes no admite `borderRadius` (falla en
    // paint(), ver box_border.dart). La franja de acento se dibuja aparte,
    // por encima de un borde uniforme, dentro de un recorte redondeado.
    final Color acento = stripeColor ?? AppColors.navy;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppElevation.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.dividerTable),
          ),
          child: Stack(
            children: <Widget>[
              Padding(padding: padding, child: child),
              if (stripe == AppCardStripe.left)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(color: acento),
                ),
              if (stripe == AppCardStripe.top)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 3,
                  child: ColoredBox(color: acento),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
