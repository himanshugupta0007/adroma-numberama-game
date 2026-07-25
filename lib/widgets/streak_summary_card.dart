import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A standalone "🔥 N day streak" card - for places the streak needs its
/// own descriptive line rather than a small header badge (the results
/// screen's own `_StreakRow` has extra round-specific "+1" logic this
/// doesn't need). Used on the home screen (below its BEST EVER card) and
/// the Daily Challenge screen.
class StreakSummaryCard extends StatelessWidget {
  const StreakSummaryCard({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.amber, size: 18),
          const SizedBox(width: 10),
          Text('$days day streak', style: AppTextStyles.display(13)),
        ],
      ),
    );
  }
}
