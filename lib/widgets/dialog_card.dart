import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}
