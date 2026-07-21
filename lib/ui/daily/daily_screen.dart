import 'package:flutter/material.dart';

import '../../state/game_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../gameplay/gameplay_screen.dart';

/// Daily challenge landing screen. The date and calendar-strip "today"
/// marker are real (`DateTime.now()`); the streak/completion status, board
/// seed, difficulty, and preview mosaic have no backing state yet and are
/// static placeholders - there's no seeded daily board generator this pass,
/// "Start today's board" just launches a normal Classic round.
class DailyScreen extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // 0=Mon .. 6=Sun

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
                          // TODO(streak): completion status is mocked - the
                          // first 6 days show "done", only today is real.
                          state: i < todayIndex
                              ? _DayState.done
                              : i == todayIndex
                                  ? _DayState.today
                                  : _DayState.future,
                          label: i == todayIndex ? '${now.day}' : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _BoardCard(),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: "Start today's board",
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const GameplayScreen(mode: GameMode.classic),
                      ),
                    ),
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
  const _BoardCard();

  @override
  Widget build(BuildContext context) {
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
                  // TODO(daily): no real seeded-board generator yet.
                  Text('SEED #0714',
                      style: AppTextStyles.mono(10.5,
                          weight: FontWeight.w600, color: AppColors.textLow)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Medium',
                    style: AppTextStyles.mono(11,
                        weight: FontWeight.w600, color: AppColors.amber)),
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
        ],
      ),
    );
  }
}
