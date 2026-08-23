import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/difficulty.dart';
import '../../state/game_mode.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../../widgets/streak_summary_card.dart';
import '../gameplay/gameplay_screen.dart';
import '../home/bottom_nav_bar.dart';
import '../home/difficulty_style.dart';

/// Daily challenge landing screen. The date, calendar-strip day markers
/// (driven by [PreferencesService.hasEverPlayedDailyOn]), today's
/// [Difficulty] tier, and the one-attempt-per-day gate are all real.
/// Today's board itself is a real, timed Rush round (see [GameplayScreen])
/// tuned to today's tier and seeded from [dailySeed], so every player sees
/// the exact same tile layout, not just the same tier.
class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String _formatDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

  /// "6h 42m" for anything an hour or longer, "12m" once it drops below -
  /// used for the countdown to the next Daily Challenge cycle.
  static String _formatCountdown(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

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
    // Reset Progress (Settings) can wipe the streak/calendar history shown
    // below from outside this screen entirely - see
    // preferencesRevisionProvider's doc for why watching the service alone
    // isn't enough to pick that up.
    ref.watch(preferencesRevisionProvider);
    final prefs = ref.watch(preferencesServiceProvider);
    final alreadyPlayed = prefs.hasPlayedCurrentDailyCycle(now);
    final nextUnlockIn = prefs.timeUntilNextDailyCycle(now);

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily challenge',
                            style: AppTextStyles.display(19)),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _formatDate(now).toUpperCase(),
                            style: AppTextStyles.mono(11,
                                weight: FontWeight.w600,
                                color: AppColors.textLow),
                          ),
                        ),
                        const SizedBox(height: 14),
                        StreakSummaryCard(days: prefs.currentStreak),
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
                                            prefs.hasEverPlayedDailyOn(weekStart
                                                .add(Duration(days: i)))
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
                          _AlreadyPlayedNotice(unlockIn: nextUnlockIn)
                        else
                          GradientButton(
                            label: "Start today's board",
                            onPressed: () => _openGameplay(context, difficulty),
                          ),
                        const SizedBox(height: 14),
                        Text(
                          alreadyPlayed
                              ? 'Next board unlocks in ${_formatCountdown(nextUnlockIn)}. '
                                  'Miss a whole day and the streak resets — no undo.'
                              : 'A new board unlocks every ${dailyCycleDuration.inHours} '
                                  'hours. Miss a whole day and the streak resets — no undo.',
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
                const Center(child: AdBannerWidget()),
                const BottomNavBar(activeTab: HomeTab.daily),
              ],
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

  @override
  Widget build(BuildContext context) {
    final chipColor = difficulty.accentColor;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          const SizedBox(height: 18),
          // Real per-tier facts replace what used to be a purely
          // decorative filler grid - the icon badge is the only piece
          // that's still illustrative rather than data-driven.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(difficulty.tierIcon, color: chipColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _BoardStatRow(
                      icon: Icons.numbers_rounded,
                      label: 'Tile range',
                      value: '1–${difficulty.maxTileValue}',
                    ),
                    const SizedBox(height: 8),
                    _BoardStatRow(
                      icon: Icons.timer_outlined,
                      label: 'Time limit',
                      value: '${difficulty.rushDuration.inSeconds}s',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One "icon · label · value" line in [_BoardCard]'s stat list.
class _BoardStatRow extends StatelessWidget {
  const _BoardStatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textLow),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.display(12,
              weight: FontWeight.w400, color: AppColors.textMid),
        ),
        const Spacer(),
        Text(value,
            style: AppTextStyles.mono(12,
                weight: FontWeight.w600, color: AppColors.textHi)),
      ],
    );
  }
}

/// Shown instead of the start button once the current cycle's one attempt
/// is spent - see [PreferencesService.hasPlayedCurrentDailyCycle].
class _AlreadyPlayedNotice extends StatelessWidget {
  const _AlreadyPlayedNotice({required this.unlockIn});

  final Duration unlockIn;

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
          const Icon(Icons.check_circle_rounded,
              color: AppColors.teal, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Today's board complete — come back in "
              '${DailyScreen._formatCountdown(unlockIn)}',
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
