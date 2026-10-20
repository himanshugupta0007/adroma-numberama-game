import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'max_width_box.dart';

/// Shared dark rounded card shell for every full-screen dialog in the
/// gameplay flow (leave/pause confirmations, how-to-play) - the default
/// [Dialog] chrome doesn't pick up [AppColors] on its own.
class DialogCard extends StatelessWidget {
  const DialogCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      // Keeps dialogs card-sized on tablets instead of nearly full-width.
      constraints: const BoxConstraints(maxWidth: MaxWidthBox.dialog),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        // Scrolls instead of overflowing when the content is taller than
        // the screen allows (short phones, large font settings).
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}
