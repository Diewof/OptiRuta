import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figura de ruta: la S del logo entre un anillo de origen y el pin de
/// destino. Es **estática y estimada** (sin posición en vivo: la app no hace
/// tracking GPS), por eso nunca lleva un camión sobre la línea.
class FiguraRuta extends StatelessWidget {
  const FiguraRuta({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 320 / 64,
      child: SvgPicture.asset(
        'assets/illustrations/figura_ruta.svg',
        semanticsLabel: 'Ruta estimada de origen a destino',
      ),
    );
  }
}
