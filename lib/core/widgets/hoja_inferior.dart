import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Hoja inferior estándar: registrar un hito o un costo sin salir de la
/// pantalla. Sube 300 ms con el fondo atenuado (0 ms con «reducir
/// movimiento»), esquinas superiores de 24 y asa de arrastre.
abstract final class HojaInferior {
  static Future<T?> mostrar<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x7314273F),
      elevation: 0,
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.efectiva(context, AppMotion.slow),
        reverseDuration: AppMotion.efectiva(context, AppMotion.base),
        curve: AppMotion.easeOut,
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              boxShadow: AppElevation.float,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.x3),
                        decoration: BoxDecoration(
                          color: AppColors.borderCard,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    builder(sheetContext),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
