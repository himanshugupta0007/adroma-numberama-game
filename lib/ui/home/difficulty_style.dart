import 'package:flutter/material.dart';

import '../../state/difficulty.dart';
import '../../theme/app_colors.dart';

/// Shared per-tier accent color/icon convention - teal for the calm/easy
/// end, amber as the neutral default, coral for the urgent/hard end - used
/// anywhere a [Difficulty] tier needs a themed badge (Daily's board card,
/// Classic's difficulty picker).
extension DifficultyStyle on Difficulty {
  Color get accentColor => switch (this) {
        Difficulty.easy => AppColors.teal,
        Difficulty.medium => AppColors.amber,
        Difficulty.hard => AppColors.coral,
      };

  IconData get tierIcon => switch (this) {
        Difficulty.easy => Icons.spa_rounded,
        Difficulty.medium => Icons.balance_rounded,
        Difficulty.hard => Icons.local_fire_department_rounded,
      };
}
