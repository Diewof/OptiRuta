import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_route_header.dart';

/// Ilustración de marca de las pantallas de autenticación, a sangre en la
/// franja superior.
///
/// Arte vectorial plano (rutas, camiones, pines) sobre el fondo de la app. Se
/// integra en la pantalla, sin borde ni recuadro: el tercio inferior de la
/// imagen se difumina con un [ShaderMask] y, encima, un fundido largo remata la
/// unión con `color.canvas`, de modo que el formulario continúa sin corte
/// visible.
///
/// Asset esperado: `assets/decor/auth_hero.png`, lienzo 1080 × 1920 px, dibujo
/// en el tercio superior y resto en `#F3F4F6`. Mientras no exista, cae en
/// [BrandRouteHeader] como reserva.
class AuthHero extends StatelessWidget {
  const AuthHero({this.compact = false, super.key});

  /// Banda más baja para pantallas largas (registro): la checklist de
  /// validación en vivo queda a la vista con menos scroll.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double factor = compact ? 0.20 : 0.30;
    final double minHeight = compact ? 140.0 : 220.0;
    final double maxHeight = compact ? 180.0 : 320.0;
    final double bandHeight =
        (mq.size.height * factor).clamp(minHeight, maxHeight) + mq.padding.top;

    return SizedBox(
      height: bandHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.white, Colors.white, Color(0x00FFFFFF)],
              stops: <double>[0.0, 0.6, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              'assets/decor/auth_hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stack,
              ) => const Center(child: BrandRouteHeader()),
            ),
          ),
          // Fundido largo del color del fondo para rematar la unión con el
          // formulario: sin costura entre la ilustración y los campos.
          const Align(alignment: Alignment.bottomCenter, child: _BottomFade()),
        ],
      ),
    );
  }
}

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x00F3F4F6), AppColors.canvas],
            ),
          ),
        ),
      ),
    );
  }
}
