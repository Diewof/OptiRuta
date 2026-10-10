import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'skeleton.dart';

/// Estado de carga reutilizable de listados y formularios: esqueleto con la
/// forma de tres tarjetas (mejor percepción de rapidez que un spinner).
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.x4),
        child: Column(
          children: <Widget>[
            SkeletonBlock(alto: 88, radio: 16),
            SizedBox(height: AppSpacing.x2),
            SkeletonBlock(alto: 88, radio: 16),
            SizedBox(height: AppSpacing.x2),
            SkeletonBlock(alto: 88, radio: 16),
          ],
        ),
      ),
    );
  }
}
