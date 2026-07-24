import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/dialog_card.dart';
import '../../widgets/gradient_button.dart';

/// Explains the one rule the whole game hinges on: which tile pairs
/// actually clear. Shown once before a player's first round, and again on
/// demand via the top bar's "?" button.
class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How to Play',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const _Rule(
            icon: Icons.join_full_rounded,
            text: 'Tap two tiles with the same number to clear them.',
          ),
          const SizedBox(height: 12),
          const _Rule(
            icon: Icons.calculate_rounded,
            text: 'Or two tiles that add up to 10 - like 4 and 6.',
          ),
          const SizedBox(height: 12),
          const _Rule(
            icon: Icons.stacked_line_chart_rounded,
            text: 'Clear the whole board before it reaches the top to win.',
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Got it', onPressed: onDismiss),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.display(13,
                weight: FontWeight.w400, color: AppColors.textMid),
          ),
        ),
      ],
    );
  }
}
