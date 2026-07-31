import 'package:flutter/material.dart';

import '../../state/difficulty.dart';
import '../../state/game_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/graph_paper_background.dart';
import '../gameplay/gameplay_screen.dart';
import 'difficulty_style.dart';

/// Shown after tapping "Play Classic" on the home screen, before any
/// [GameplayScreen] round starts - lets the player pick a [Difficulty] tier
/// for their Classic round instead of always playing at [Difficulty.medium].
/// Tapping a tier card starts that round immediately; there's no separate
/// confirm step, matching the rest of the app's one-tap navigation (e.g. the
/// Daily Challenge's single start button).
class ClassicDifficultyScreen extends StatelessWidget {
  const ClassicDifficultyScreen({super.key});

  void _start(BuildContext context, Difficulty difficulty) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameplayScreen(
          mode: GameMode.classic,
          difficulty: difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Choose difficulty', style: AppTextStyles.display(18)),
      ),
      body: GraphPaperBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick a pace for your Classic round.',
                  style: AppTextStyles.display(12.5,
                      weight: FontWeight.w400, color: AppColors.textMid),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    itemCount: Difficulty.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final difficulty = Difficulty.values[index];
                      return _DifficultyOptionCard(
                        difficulty: difficulty,
                        onTap: () => _start(context, difficulty),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable tier card: icon badge, title, a plain-language description
/// of that tier's pace and pair-finding difficulty, plus the two stats that
/// actually drive it (row interval, tile range) so the description isn't
/// the only place those numbers show up.
class _DifficultyOptionCard extends StatelessWidget {
  const _DifficultyOptionCard({
    required this.difficulty,
    required this.onTap,
  });

  final Difficulty difficulty;
  final VoidCallback onTap;

  static String _description(Difficulty difficulty) => switch (difficulty) {
        Difficulty.easy =>
          'Rows rise slowly, and matching numbers are easy to spot.',
        Difficulty.medium =>
          'A steady pace - matching numbers take a little more effort to find.',
        Difficulty.hard =>
          'Rows rise fast, and matching numbers are hard to find together.',
      };

  @override
  Widget build(BuildContext context) {
    final accent = difficulty.accentColor;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(difficulty.tierIcon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(difficulty.label, style: AppTextStyles.display(16)),
                        const SizedBox(height: 4),
                        Text(
                          _description(difficulty),
                          style: AppTextStyles.display(12.5,
                              weight: FontWeight.w400,
                              color: AppColors.textMid),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textLow),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      icon: Icons.timer_outlined,
                      label: 'New row every',
                      value: '${difficulty.autoRowIntervalSeconds.toStringAsFixed(0)}s',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.numbers_rounded,
                      label: 'Tile range',
                      value: '1–${difficulty.maxTileValue}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.textLow),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.display(10.5,
                  weight: FontWeight.w400, color: AppColors.textLow),
            ),
          ),
          Text(value,
              style: AppTextStyles.mono(11.5, color: AppColors.textHi)),
        ],
      ),
    );
  }
}
