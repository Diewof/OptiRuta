import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../viajes/domain/entities/categoria_costo.dart';

/// Color de la barra de cada costo en el desglose del Resumen, para
/// reconocerlos de un vistazo (ACPM siempre rojo). Solo se usa en esas barras.
extension ColorCosto on CategoriaCosto {
  Color get color => switch (this) {
    CategoriaCosto.acpm => AppColors.brandRed,
    CategoriaCosto.peaje => const Color(0xFF2F6DB5),
    CategoriaCosto.cargue => AppColors.success,
    CategoriaCosto.descargue => AppColors.warning,
    CategoriaCosto.parqueadero => const Color(0xFF7A5BA6),
    CategoriaCosto.comision => const Color(0xFF1F8A9E),
    CategoriaCosto.aceite => const Color(0xFF8A5A2B),
    CategoriaCosto.lavado => const Color(0xFF5BA4D6),
    CategoriaCosto.engrase => const Color(0xFF6B7280),
    CategoriaCosto.mantenimientoAmortizado => AppColors.navy,
    CategoriaCosto.otro => AppColors.textDisabled,
  };
}

/// Costos fijos del período que no son una categoría de viaje.
abstract final class ColoresCostoFijo {
  static const Color mantenimiento = AppColors.navy;
  static const Color sueldo = AppColors.slate;
}
