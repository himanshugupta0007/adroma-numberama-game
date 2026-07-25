import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/difficulty.dart';
import '../../state/game_mode.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../../widgets/message_dialog.dart';
import '../gameplay/gameplay_screen.dart';
import '../home/bottom_nav_bar.dart';

/// Shown when a round ends, either by clearing the board ([GamePhase.won])
/// or falling short ([GamePhase.lost] - the board filling up while stuck,
/// for Classic, or the Daily Challenge Rush countdown hitting zero with
/// tiles still left). [score]/[pairs] are the real final values from that
/// round, passed in at the moment of transition rather than re-read from
/// the provider (which may already have been reset for the next round by
/// the time this screen builds).
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({
    super.key,
    required this.score,
    required this.pairs,
    required this.bestCombo,
    required this.isNewBest,
    required this.mode,
    required this.won,
    this.isDaily = false,
    this.difficulty = Difficulty.medium,
    this.dailyStars = 0,
    this.elapsed = Duration.zero,
    this.streakJustExtended = false,
    this.classicRoundNumber = 1,
    this.attemptHistory = const [],
  });

  final int score;
  final int pairs;

  /// Highest combo streak reached during the round.
  final int bestCombo;

  /// Whether [score] beat every previous round's score.
  final bool isNewBest;
  final GameMode mode;
  final bool won;

  /// Whether this was today's Daily Challenge round rather than an ordinary
  /// Classic/Rush round - swaps "Play again" for a "Done for today" CTA
  /// (there's only one daily attempt) and switches the share card over to
  /// the star rating below instead of raw score.
  final bool isDaily;

  /// Only meaningful when [isDaily] - which tier today's board was.
  final Difficulty difficulty;

  /// Only meaningful when [isDaily] - see
  /// `_GameplayScreenState._starsForDaily`.
  final int dailyStars;

  /// Real wall-clock time the round took, start to finish - see
  /// [GameState.startedAt].
  final Duration elapsed;

  /// Only meaningful when [isDaily] - whether *this* round actually
  /// extended the streak by one (a consecutive day), per
  /// [PreferencesService.registerDailyPlayed]'s return value. `false` when
  /// a day was skipped and the streak restarted at 1 instead - the "+1"
  /// badge only makes sense to show in the former case.
  final bool streakJustExtended;

  /// Classic only - this round's 1-based index among every Classic round
  /// ever played, from [PreferencesService.registerClassicRoundPlayed].
  /// Classic has no daily puzzle index of its own, unlike the Daily
  /// Challenge, so this stands in for the share card's Wordle-style
  /// "Numberama #N".
  final int classicRoundNumber;

  /// One entry per pair attempt this round, in order - see
  /// [GameState.attemptHistory]. The share card's mosaic is built directly
  /// from this instead of a decorative placeholder.
  final List<bool> attemptHistory;

  static String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(preferencesServiceProvider).currentStreak;
    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Always returns all the way to Home regardless of how
                        // deep the stack is (Classic: Home -> Results; Daily:
                        // Home -> Daily -> Results) - "Done for today"/"Play
                        // again" below cover the in-flow paths, this is the one
                        // way out of the results screen entirely.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.of(context)
                                .popUntil((route) => route.isFirst),
                            icon: const Icon(Icons.home_rounded,
                                color: AppColors.textLow),
                            tooltip: 'Back to Home',
                          ),
                        ),
                        Text(
                          won
                              ? 'ROUND COMPLETE'
                              : (isDaily ? "TIME'S UP" : 'BOARD FULL'),
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 8),
                        Text('$score',
                            style: AppTextStyles.mono(46,
                                color: AppColors.textHi)),
                        const SizedBox(height: 8),
                        // A new best takes priority over the loss badge - getting
                        // stuck is still worth celebrating if the score that got
                        // you there beat everything before it. A win with no new
                        // best shows neither badge.
                        if (isNewBest)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('NEW BEST',
                                style: AppTextStyles.mono(10.5,
                                    weight: FontWeight.w600,
                                    color: AppColors.teal)),
                          )
                        else if (!won)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                                isDaily ? 'OUT OF TIME' : 'NO MORE ROOM',
                                style: AppTextStyles.mono(10.5,
                                    weight: FontWeight.w600,
                                    color: AppColors.coral)),
                          ),
                        if (isDaily) ...[
                          const SizedBox(height: 10),
                          _StarsRow(stars: dailyStars),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            // Same "never show x0" rule as the in-round badge -
                            // a round with zero pairs cleared still reads "x1".
                            Expanded(
                              child: _StatChip(
                                value: 'x${bestCombo == 0 ? 1 : bestCombo}',
                                label: 'Combo',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child:
                                    _StatChip(value: '$pairs', label: 'Pairs')),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                value: _formatElapsed(elapsed),
                                label: 'Time',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _StreakRow(
                            days: streak, justExtended: streakJustExtended),
                        const SizedBox(height: 20),
                        _ShareCard(
                          attemptHistory: attemptHistory,
                          score: score,
                          isDaily: isDaily,
                          difficulty: difficulty,
                          dailyStars: dailyStars,
                          classicRoundNumber: classicRoundNumber,
                        ),
                        const SizedBox(height: 22),
                        GradientButton(
                          // The daily board is one attempt only - there's nothing
                          // to replay, so this just returns to the Daily
                          // Challenge screen instead of starting a fresh round.
                          label: isDaily ? 'Done for today' : 'Play again',
                          onPressed: () {
                            if (isDaily) {
                              Navigator.pop(context);
                              return;
                            }
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GameplayScreen(mode: mode),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => showMessageDialog(
                                context, 'Sharing — coming soon'),
                            child: const Text('Share result'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const BottomNavBar(activeTab: HomeTab.results),
              ],
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

/// Daily Challenge only: 3 stars, filled amber up to [stars] and outlined
/// beyond it - the Wordle-style "how well did you do today" readout.
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            color: AppColors.amber,
            size: 28,
          ),
      ],
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.days, required this.justExtended});

  final int days;

  /// Whether this specific round is what pushed the streak to [days] - see
  /// [ResultsScreen.streakJustExtended]. Only then does the "+1" badge
  /// actually describe what just happened, so it's the one gate on
  /// whether it renders at all.
  final bool justExtended;

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
          if (justExtended)
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
  const _ShareCard({
    required this.attemptHistory,
    required this.score,
    required this.isDaily,
    required this.difficulty,
    required this.dailyStars,
    required this.classicRoundNumber,
  });

  final List<bool> attemptHistory;
  final int score;
  final bool isDaily;
  final Difficulty difficulty;
  final int dailyStars;
  final int classicRoundNumber;

  /// Fixed 9-wide mosaic size the card was designed for. [attemptHistory]
  /// rarely lines up with this exactly - a short round leaves the tail
  /// unplayed (shown dim), a long one has more attempts than cells (only
  /// the most recent [_mosaicSize] are shown, so the mosaic reflects how
  /// the round actually finished rather than just its opening moves).
  static const _mosaicSize = 27;

  /// Teal for a cleared pair, coral for a miss - the same success/failure
  /// colors used elsewhere on this screen (the "NEW BEST" badge, the
  /// "OUT OF TIME"/"NO MORE ROOM" badge) - dimmed surface for any cell
  /// beyond how many attempts the round actually had.
  List<Color> _mosaicColors() {
    final recent = attemptHistory.length > _mosaicSize
        ? attemptHistory.sublist(attemptHistory.length - _mosaicSize)
        : attemptHistory;
    return [
      for (var i = 0; i < _mosaicSize; i++)
        i < recent.length
            ? (recent[i] ? AppColors.teal : AppColors.coral)
            : AppColors.surfaceRaised,
    ];
  }

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
              for (final color in _mosaicColors())
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isDaily
                ? 'Numberama Daily · ${dailySeedLabel(DateTime.now())} · '
                    '${difficulty.label} · ${'★' * dailyStars}'
                    '${'☆' * (3 - dailyStars)}'
                : 'Numberama #$classicRoundNumber · $score pts',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
