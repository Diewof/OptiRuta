import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marca gráfica de OptiRuta.
///
/// Muestra `assets/branding/logo.png` sobre un disco blanco, para que el logo
/// (aro y texto azul marino, vías grises, pines rojos, fondo transparente) se
/// lea también sobre superficies oscuras como el masthead. Si el asset falta,
/// dibuja un sello sobrio de reserva.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 44, this.chip = true, super.key});

  final double size;

  /// Envuelve el logo en un disco blanco (por defecto). Poner `false` sobre
  /// superficies claras.
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      'assets/branding/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _FallbackMark(size: size),
    );

    return Semantics(
      label: 'OptiRuta',
      image: true,
      child: chip
          ? Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(size * 0.06),
              decoration: const BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
              ),
              child: image,
            )
          : SizedBox(width: size, height: size, child: image),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.34,
        height: size * 0.34,
        decoration: const BoxDecoration(
          color: AppColors.brandRed,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
