import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_mode.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../daily/daily_screen.dart';
import '../gameplay/gameplay_screen.dart';
import 'bottom_nav_bar.dart';
import 'mode_card.dart';

/// Landing screen: wordmark, streak badge, a Classic/Daily Challenge mode
/// picker, and the app's bottom nav.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openGameplay(BuildContext context, GameMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameplayScreen(mode: mode)),
    );
  }

  void _openDaily(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(preferencesServiceProvider).currentStreak;
    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                // Fixed at the top, outside the centered section below - the
                // wordmark/streak header shouldn't drift toward the middle
                // of the screen along with the mode cards.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const _WordmarkIcon(),
                            const SizedBox(width: 10),
                            Text('NUMBERAMA', style: AppTextStyles.heading),
                          ],
                        ),
                        _StreakBadge(days: streak),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 34, top: 2),
                      child: Text(
                        'TAP · SUM · CLEAR',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ModeCard(
                            icon: Icons.grid_view_rounded,
                            iconColor: AppColors.amber,
                            title: 'Classic',
                            description:
                                'Clear the grid before it fills up. No clock, just pressure.',
                            action: GradientButton(
                              label: 'Play Classic',
                              onPressed: () =>
                                  _openGameplay(context, GameMode.classic),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ModeCard(
                            icon: Icons.calendar_today_rounded,
                            iconColor: AppColors.teal,
                            title: 'Daily Challenge',
                            description:
                                'A new board every day. Keep the streak alive.',
                            borderColor: AppColors.teal.withValues(alpha: 0.25),
                            action: ElevatedButton(
                              onPressed: () => _openDaily(context),
                              child: const Text('Play Daily'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const BottomNavBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordmarkIcon extends StatelessWidget {
  const _WordmarkIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _WordmarkPainter()),
    );
  }
}

class _WordmarkPainter extends CustomPainter {
  const _WordmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 17)
      ..quadraticBezierTo(12, 4, 20, 17);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(4, 17), 2.6, Paint()..color = AppColors.amber);
    canvas.drawCircle(const Offset(20, 17), 2.6, Paint()..color = AppColors.teal);
  }

  @override
  bool shouldRepaint(covariant _WordmarkPainter oldPainter) => false;
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.amber, size: 15),
          const SizedBox(width: 5),
          Text('$days', style: AppTextStyles.mono(13, color: AppColors.amber)),
        ],
      ),
    );
  }
}
