import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ilustraciones de marca (carretera en S del logo, anillo y pin). Una por
/// pantalla, solo en vacío, éxito de cierre y error: siempre con función.
enum IlustracionEstado {
  sinViaje('assets/illustrations/sin_viaje.svg'),
  viajeCerrado('assets/illustrations/viaje_cerrado.svg'),
  rutaInterrumpida('assets/illustrations/ruta_interrumpida.svg');

  const IlustracionEstado(this.asset);
  final String asset;
}

class IlustracionEstadoView extends StatelessWidget {
  const IlustracionEstadoView(this.ilustracion, {this.ancho = 200, super.key});

  final IlustracionEstado ilustracion;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(ilustracion.asset, width: ancho),
    );
  }
}
