import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Faint repeating grid drawn behind game/menu screens for the "graph
/// paper" canvas look. Purely decorative - sits behind child content via a
/// [Stack].
class GraphPaperBackground extends StatelessWidget {
  const GraphPaperBackground({super.key, this.child});

  final Widget? child;

  static const double _spacing = 24;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgNavy,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _GraphPaperPainter()),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _GraphPaperPainter extends CustomPainter {
  static const double _spacing = GraphPaperBackground._spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPaperPainter oldPainter) => false;
}
