import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's small vector mark: an arc between an amber and a teal dot,
/// echoing the tile-pairing mechanic. Drawn with a [CustomPainter] rather
/// than a bundled image asset, so it renders crisply at any size - the home
/// screen's header and the results screen's shareable card both use this
/// same widget instead of each needing their own bitmap.
class WordmarkIcon extends StatelessWidget {
  const WordmarkIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    // _WordmarkPainter's path/circle coordinates are hardcoded for a 24x24
    // canvas - FittedBox scales that fixed painting up to `size` instead of
    // needing every coordinate parameterized.
    return SizedBox(
      width: size,
      height: size,
      child: const FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _WordmarkPainter()),
        ),
      ),
    );
  }
}

class _WordmarkPainter extends CustomPainter {
  const _WordmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 17)
      ..quadraticBezierTo(12, 4, 20, 17);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
        const Offset(4, 17), 2.6, Paint()..color = AppColors.amber);
    canvas.drawCircle(
        const Offset(20, 17), 2.6, Paint()..color = AppColors.teal);
  }

  @override
  bool shouldRepaint(covariant _WordmarkPainter oldPainter) => false;
}
