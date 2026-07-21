import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../../game/selection_manager.dart';
import '../../game/tile_component.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The game's signature interaction: a glowing arc between the two
/// currently-selected tiles, labeled with the pairing rule they satisfy.
/// Driven entirely by [SelectionManager.selectedTilesListenable] - no mock
/// data, this only ever shows a real, currently-valid-looking selection.
///
/// Must be stacked with the exact same bounds as the [GameWidget] it
/// overlays: tile positions come from Flame's [PositionComponent
/// .absoluteCenter], which is 1:1 with this widget's local coordinate space
/// only because [NumberamaGame] uses no camera/viewport transform.
class SumArcOverlay extends StatelessWidget {
  const SumArcOverlay({super.key, required this.selectionManager});

  final SelectionManager selectionManager;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TileComponent>>(
      valueListenable: selectionManager.selectedTilesListenable,
      builder: (context, selected, _) {
        if (selected.length != 2) return const SizedBox.shrink();

        final tileA = selected[0];
        final tileB = selected[1];
        final a = tileA.absoluteCenter.toOffset();
        final b = tileB.absoluteCenter.toOffset();
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final controlY = (a.dy < b.dy ? a.dy : b.dy) - 26;
        final control = Offset(mid.dx, controlY);
        final label = tileA.value == tileB.value
            ? '${tileA.value} = ${tileB.value}'
            : '${tileA.value} + ${tileB.value} = 10';

        return IgnorePointer(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArcPainter(a: a, b: b, control: control),
                ),
              ),
              Positioned(
                left: mid.dx,
                top: controlY - 14,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -1),
                  child: _SumPill(label: label),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension on Vector2 {
  Offset toOffset() => Offset(x, y);
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.a, required this.b, required this.control});

  final Offset a;
  final Offset b;
  final Offset control;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.teal.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(a, 6, Paint()..color = AppColors.amber);
    canvas.drawCircle(b, 6, Paint()..color = AppColors.teal);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldPainter) =>
      oldPainter.a != a || oldPainter.b != b;
}

class _SumPill extends StatelessWidget {
  const _SumPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.amber, AppColors.teal],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(11, color: AppColors.bgDeep),
      ),
    );
  }
}
