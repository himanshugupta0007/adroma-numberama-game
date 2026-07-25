import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/difficulty.dart';
import '../../state/game_mode.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../gameplay/gameplay_screen.dart';

/// Daily challenge landing screen. The date, calendar-strip day markers
/// (driven by [PreferencesService.hasEverPlayedDailyOn]), today's
/// [Difficulty] tier, and the one-attempt-per-day gate are all real; only
/// the preview mosaic has no backing state yet and is a static placeholder.
/// Today's board itself is a real, timed Rush round (see [GameplayScreen])
/// tuned to today's tier - the seed label is a stable per-date identifier,
/// not yet a literal RNG seed, so the exact tile layout still varies
/// between plays of the "same" seed.
class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String _formatDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

  void _openGameplay(BuildContext context, Difficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameplayScreen(
          mode: GameMode.classic,
          difficulty: difficulty,
          isDaily: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // 0=Mon .. 6=Sun
    final weekStart = now.subtract(Duration(days: todayIndex));
    final difficulty = Difficulty.forDate(now);
    final prefs = ref.watch(preferencesServiceProvider);
    final alreadyPlayed = prefs.hasPlayedDailyOn(now);

    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: AppColors.textHi),
                      ),
                      Text('Daily challenge', style: AppTextStyles.display(19)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      _formatDate(now).toUpperCase(),
                      style: AppTextStyles.mono(11,
                          weight: FontWeight.w600, color: AppColors.textLow),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 7; i++)
                        _CalendarDay(
                          letter: _dayLetters[i],
                          state: i == todayIndex
                              ? (alreadyPlayed
                                  ? _DayState.done
                                  : _DayState.today)
                              : i < todayIndex &&
                                      prefs.hasEverPlayedDailyOn(
                                          weekStart.add(Duration(days: i)))
                                  ? _DayState.done
                                  : _DayState.future,
                          label: i == todayIndex ? '${now.day}' : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _BoardCard(difficulty: difficulty, date: now),
                  const SizedBox(height: 20),
                  if (alreadyPlayed)
                    const _AlreadyPlayedNotice()
                  else
                    GradientButton(
                      label: "Start today's board",
                      onPressed: () => _openGameplay(context, difficulty),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'New board unlocks at midnight. Miss a day and the streak '
                    'resets — no undo.',
                    style: AppTextStyles.display(
                      11.5,
                      weight: FontWeight.w400,
                      color: AppColors.textLow,
                    ).copyWith(fontStyle: FontStyle.italic),
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

enum _DayState { done, today, future }

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.letter, required this.state, this.label});

  final String letter;
  final _DayState state;
  final String? label;

  @override
  Widget build(BuildContext context) {
    late final Widget dot;
    switch (state) {
      case _DayState.done:
        dot = _dotContainer(
          color: AppColors.amber,
          child: Text('✓',
              style: AppTextStyles.display(13,
                  weight: FontWeight.w700, color: AppColors.onAmber)),
        );
      case _DayState.today:
        dot = Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal, width: 1.6),
          ),
          alignment: Alignment.center,
          child: Text(label ?? '',
              style: AppTextStyles.mono(11, color: AppColors.teal)),
        );
      case _DayState.future:
        dot = _dotContainer(
          color: AppColors.surface,
          child: const SizedBox.shrink(),
        );
    }

    return Column(
      children: [
        dot,
        const SizedBox(height: 6),
        Text(letter,
            style: AppTextStyles.mono(9,
                weight: FontWeight.w600, color: AppColors.textLow)),
      ],
    );
  }

  Widget _dotContainer({required Color color, required Widget child}) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.difficulty, required this.date});

  final Difficulty difficulty;
  final DateTime date;

  /// Same accent-per-tier convention as the rest of the app: teal reads as
  /// the calm/easy end, amber as the neutral default, coral as the
  /// urgent/hard end (it was Rush's color when Rush still existed).
  static Color _chipColor(Difficulty difficulty) => switch (difficulty) {
        Difficulty.easy => AppColors.teal,
        Difficulty.medium => AppColors.amber,
        Difficulty.hard => AppColors.coral,
      };

  @override
  Widget build(BuildContext context) {
    final chipColor = _chipColor(difficulty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's board", style: AppTextStyles.display(14)),
                  const SizedBox(height: 4),
                  Text(dailySeedLabel(date),
                      style: AppTextStyles.mono(10.5,
                          weight: FontWeight.w600, color: AppColors.textLow)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(difficulty.label,
                    style: AppTextStyles.mono(11,
                        weight: FontWeight.w600, color: chipColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            children: [
              for (var i = 1; i <= 24; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: i % 3 == 0 ? AppColors.bgNavy : AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.textLow),
              const SizedBox(width: 6),
              Text(
                '${dailyRushDuration.inSeconds}s to clear the whole board',
                style: AppTextStyles.display(
                  11.5,
                  weight: FontWeight.w400,
                  color: AppColors.textLow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the start button once today's one attempt is spent -
/// see [PreferencesService.hasPlayedDailyOn].
class _AlreadyPlayedNotice extends StatelessWidget {
  const _AlreadyPlayedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Today's board complete — come back tomorrow",
              textAlign: TextAlign.center,
              style: AppTextStyles.display(13,
                  weight: FontWeight.w500, color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
