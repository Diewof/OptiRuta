import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';

/// Bloque de esqueleto con brillo suave. Con «reducir movimiento» queda
/// estático. Se compone para imitar la estructura real de la pantalla.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    this.alto = 16,
    this.ancho,
    this.radio = AppRadius.md,
    super.key,
  });

  final double alto;
  final double? ancho;
  final double radio;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reducir(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radio),
        child: SizedBox(
          height: widget.alto,
          width: widget.ancho,
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? child) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.5 + 3 * _c.value, 0),
                    end: Alignment(-0.5 + 3 * _c.value, 0),
                    colors: const <Color>[
                      AppColors.navyTint,
                      Color(0xFFF8F9FB),
                      AppColors.navyTint,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
