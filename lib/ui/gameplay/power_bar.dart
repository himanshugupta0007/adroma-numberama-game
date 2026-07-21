import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The 5-slot power-up strip. Static/inert this pass - no power-up set has
/// been designed yet, so these render as visual chrome only (no tap
/// handlers), per the mockup's icon set (undo / shuffle / ad-gated hint /
/// star / redo), approximated with Material icons.
class PowerBar extends StatelessWidget {
  const PowerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PowerSlot(icon: Icons.undo_rounded, count: 2),
          _PowerSlot(icon: Icons.shuffle_rounded, count: 1),
          _PowerSlot(icon: Icons.lightbulb_outline_rounded, adGated: true),
          _PowerSlot(icon: Icons.auto_awesome_rounded, count: 3),
          _PowerSlot(icon: Icons.fast_forward_rounded, count: 1),
        ],
      ),
    );
  }
}

class _PowerSlot extends StatelessWidget {
  const _PowerSlot({required this.icon, this.count, this.adGated = false});

  final IconData icon;
  final int? count;
  final bool adGated;

  @override
  Widget build(BuildContext context) {
    final inert = count == null && !adGated;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: inert
                  ? AppColors.textLow.withValues(alpha: 0.55)
                  : AppColors.textHi,
            ),
          ),
          if (count != null)
            Positioned(
              bottom: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bgNavy,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.surfaceRaised),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.mono(9, color: AppColors.textMid),
                ),
              ),
            ),
          if (adGated)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.play_arrow_rounded,
                    size: 10, color: AppColors.bgDeep),
              ),
            ),
        ],
      ),
    );
  }
}
