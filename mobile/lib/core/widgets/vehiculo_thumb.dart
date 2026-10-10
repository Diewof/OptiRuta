import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/vehiculos/domain/entities/tipo_vehiculo.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Miniatura 4:3 de un vehículo. Mientras no exista la foto real de la flota
/// muestra la imagen de reemplazo de marca según el tipo (doble troque o
/// mula); nunca deja un hueco.
class VehiculoThumb extends StatelessWidget {
  const VehiculoThumb({required this.tipo, this.ancho = 72, super.key});

  final TipoVehiculo tipo;
  final double ancho;

  String get _asset => switch (tipo) {
    TipoVehiculo.dobleTroque => 'assets/vehiculos/doble_troque.svg',
    TipoVehiculo.mula => 'assets/vehiculos/mula.svg',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: tipo.etiqueta,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: ColoredBox(
            color: AppColors.navyTint,
            child: SizedBox(
              width: ancho,
              height: ancho * 3 / 4,
              child: SvgPicture.asset(_asset, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}
