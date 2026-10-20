import 'package:flutter/material.dart';

/// Centres [child] and caps its width at [maxWidth], so on tablets and
/// unfolded foldables the layout stays phone-shaped in the middle of the
/// screen instead of stretching edge to edge. On phones (narrower than
/// [maxWidth]) it's a no-op. Goes *inside* each screen's [SafeArea] and
/// background, so the graph-paper background still fills the whole screen.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({super.key, this.maxWidth = 600, required this.child});

  /// The widest the whole screen layout gets - see [MaxWidthBox].
  static const double screen = 600;

  /// The widest a dialog or popup card gets.
  static const double dialog = 420;

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Center(
          child: SizedBox(width: maxWidth, child: child),
        );
      },
    );
  }
}
