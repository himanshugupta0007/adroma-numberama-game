import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/power_up.dart';
import '../state/preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dialog_card.dart';

/// Shows the "pick a power-up" reward for every unclaimed level milestone
/// (each [levelsPerPowerUpReward] levels), one dialog after another. A
/// no-op when nothing is pending. Not dismissible by tapping outside, so the
/// player always makes a choice.
Future<void> maybeShowPowerUpReward(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(preferencesServiceProvider);
  while (prefs.pendingPowerUpRewards > 0) {
    if (!context.mounted) return;
    final picked = await showDialog<PowerUpType>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PowerUpRewardDialog(),
    );
    if (picked == null) return;
    await prefs.claimPowerUpReward(picked);
  }
}

class _PowerUpRewardDialog extends StatelessWidget {
  const _PowerUpRewardDialog();

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Level reward!',
            style: AppTextStyles.display(20, color: AppColors.textHi),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a power-up to add to your stash.',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              13,
              weight: FontWeight.w500,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final type in PowerUpType.values)
                _RewardTile(
                  type: type,
                  onTap: () => Navigator.pop(context, type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.type, required this.onTap});

  final PowerUpType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(type.icon, size: 30, color: AppColors.amber),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${type.label} +1',
          style: AppTextStyles.display(
            11,
            weight: FontWeight.w500,
            color: AppColors.textMid,
          ),
        ),
      ],
    );
  }
}
