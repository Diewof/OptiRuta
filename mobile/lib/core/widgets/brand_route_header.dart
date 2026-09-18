import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_mark.dart';

/// Cabecera decorativa breve de las pantallas de autenticación.
///
/// Una polilínea de ruta fina y **estática** (evoca el motivo del logo) que
/// cruza el ancho, con la marca centrada sobre un hueco limpio. ~48 dp de alto,
/// sin animación ni assets nuevos.
class BrandRouteHeader extends StatelessWidget {
  const BrandRouteHeader({super.key});

  static const double _height = 48;
  static const double _mark = 30;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _RoutePainter()),
            ),
          ),
          // Disco del color del fondo: abre un hueco limpio en la línea para
          // que la marca se lea sin cruces.
          Container(
            width: _mark + 16,
            height: _mark + 16,
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const BrandMark(size: _mark, chip: false),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final List<Offset> points = <Offset>[
      Offset(size.width * 0.02, cy + size.height * 0.26),
      Offset(size.width * 0.22, cy - size.height * 0.30),
      Offset(size.width * 0.42, cy + size.height * 0.08),
      Offset(size.width * 0.58, cy + size.height * 0.08),
      Offset(size.width * 0.78, cy - size.height * 0.30),
      Offset(size.width * 0.98, cy + size.height * 0.26),
    ];

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.borderCard,
    );

    final Paint node = Paint()..color = AppColors.borderInput;
    for (final Offset p in points) {
      canvas.drawCircle(p, 3, node);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => false;
}
