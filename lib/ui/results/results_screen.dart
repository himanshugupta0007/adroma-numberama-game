import 'package:flutter/material.dart';

import '../../state/game_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../gameplay/gameplay_screen.dart';

/// Shown when a round ends, either by clearing the board ([GamePhase.won])
/// or by the board filling up while the player was stuck ([GamePhase.lost]
/// - reachable now that [GridComponent.maxRows] gives the board a real
/// ceiling). [score]/[pairs] are the real final values from that round,
/// passed in at the moment of transition rather than re-read from the
/// provider (which may already have been reset for the next round by the
/// time this screen builds).
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.score,
    required this.pairs,
    required this.mode,
    required this.won,
  });

  final int score;
  final int pairs;
  final GameMode mode;
  final bool won;

  // TODO(stats): combo tracking, round timer, and best-score persistence
  // don't exist yet - these are static placeholders matching the mockup.
  static const _mockCombo = 'x5';
  static const _mockTime = '2:14';
  static const _mockStreakDays = 15;

  static const _blockPattern = [
    AppColors.amber, AppColors.teal, AppColors.surfaceRaised,
    AppColors.amber, AppColors.amber, AppColors.teal,
    AppColors.surfaceRaised, AppColors.teal, AppColors.amber,
    AppColors.teal, AppColors.amber, AppColors.surfaceRaised,
    AppColors.teal, AppColors.teal, AppColors.amber,
    AppColors.surfaceRaised, AppColors.amber, AppColors.teal,
    AppColors.amber, AppColors.amber, AppColors.teal,
    AppColors.surfaceRaised, AppColors.teal, AppColors.amber,
    AppColors.teal, AppColors.surfaceRaised, AppColors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(won ? 'ROUND COMPLETE' : 'BOARD FULL',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Text('$score', style: AppTextStyles.mono(46, color: AppColors.textHi)),
                  const SizedBox(height: 8),
                  if (won)
                    // TODO(best-score): always shown on a win - no
                    // persisted best yet.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('NEW BEST',
                          style: AppTextStyles.mono(10.5,
                              weight: FontWeight.w600, color: AppColors.teal)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('NO MORE ROOM',
                          style: AppTextStyles.mono(10.5,
                              weight: FontWeight.w600, color: AppColors.coral)),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: _StatChip(value: _mockCombo, label: 'Combo')),
                      const SizedBox(width: 8),
                      Expanded(child: _StatChip(value: '$pairs', label: 'Pairs')),
                      const SizedBox(width: 8),
                      const Expanded(child: _StatChip(value: _mockTime, label: 'Time')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _StreakRow(days: _mockStreakDays),
                  const SizedBox(height: 20),
                  _ShareCard(pattern: _blockPattern, score: score),
                  const SizedBox(height: 22),
                  GradientButton(
                    label: 'Play again',
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameplayScreen(mode: mode),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sharing — coming soon')),
                      ),
                      child: const Text('Share result'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.mono(15, color: AppColors.amber)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.amber, size: 18),
              const SizedBox(width: 10),
              Text('$days day streak', style: AppTextStyles.display(13)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('+1',
                style: AppTextStyles.mono(11,
                    weight: FontWeight.w600, color: AppColors.teal)),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.pattern, required this.score});

  final List<Color> pattern;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share your run',
              style: AppTextStyles.display(12.5,
                  weight: FontWeight.w500, color: AppColors.textMid)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 9,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: [
              for (final color in pattern)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Numberama #142 · $score pts', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
