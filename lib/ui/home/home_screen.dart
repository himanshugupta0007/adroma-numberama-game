import 'package:flutter/material.dart';

import '../../state/game_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../daily/daily_screen.dart';
import '../gameplay/gameplay_screen.dart';
import 'bottom_nav_bar.dart';
import 'mode_card.dart';

/// Landing screen: wordmark, streak badge, Classic/Rush mode picker, a
/// shortcut into today's Daily board, and the app's bottom nav.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // TODO(streak): no streak tracking exists yet - static placeholder.
  static const _mockStreakDays = 14;

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
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
                            const _StreakBadge(days: _mockStreakDays),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 34, top: 2),
                          child: Text(
                            'TAP · SUM · CLEAR',
                            style: AppTextStyles.caption,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                          icon: Icons.timer_rounded,
                          iconColor: AppColors.coral,
                          title: 'Rush · 60s',
                          description:
                              'Chain as many pairs as you can before the timer runs out.',
                          borderColor: AppColors.coral.withValues(alpha: 0.25),
                          action: ElevatedButton(
                            onPressed: () =>
                                _openGameplay(context, GameMode.rush),
                            child: const Text('Start Rush'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DailyStrip(onTap: () => _openDaily(context)),
                      ],
                    ),
                  ),
                ),
                BottomNavBar(onDailyTap: () => _openDaily(context)),
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

class _DailyStrip extends StatelessWidget {
  const _DailyStrip({required this.onTap});

  final VoidCallback onTap;

  // TODO(daily): no real day counter/unlock schedule yet - static placeholder.
  static const _mockDayLabel = "DAY 14 · NEW AT MIDNIGHT";

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's board",
                        style: AppTextStyles.display(13.5)),
                    Text(_mockDayLabel, style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLow, size: 20),
          ],
        ),
      ),
    );
  }
}
