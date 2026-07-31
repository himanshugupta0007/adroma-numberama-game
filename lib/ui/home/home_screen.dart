import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/rate_service.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/dialog_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../../widgets/wordmark_icon.dart';
import 'bottom_nav_bar.dart';
import 'classic_difficulty_screen.dart';
import 'mode_card.dart';

/// Landing screen: a centered hero wordmark, a best-score summary (today's/
/// this month's/this year's, plus the all-time best), and the Classic mode
/// card. Daily Challenge and Settings are reached from the bottom nav, not
/// from this screen's main content - the streak lives on the Daily
/// Challenge screen itself, since Classic play doesn't affect it.
///
/// Also owns the automatic "Rate Numberama" prompt: [HomeScreen] is created
/// exactly once per cold launch (every path back to it - "Back to Home",
/// "Done for today" - pops or `popUntil`s the existing instance rather than
/// pushing a new one), so [initState] firing once is the same event as "the
/// app was opened" - see [PreferencesService.shouldShowRatePrompt].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const _monthNames = [
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

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowRatePrompt());
  }

  /// Shows the "Rate Numberama" prompt if [PreferencesService.
  /// shouldShowRatePrompt] says it's due - see that method for the actual
  /// 4th-open / every-4-days cadence. Records today as the last-shown day
  /// up front (not after the dialog resolves) so a quick re-launch before
  /// the dialog is dismissed can't re-trigger it.
  Future<void> _maybeShowRatePrompt() async {
    if (!mounted) return;
    final prefs = ref.read(preferencesServiceProvider);
    if (!prefs.shouldShowRatePrompt()) return;
    await prefs.setLastRatePromptDate(DateTime.now());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RatePromptDialog(
        onRate: () async {
          Navigator.pop(dialogContext);
          await RateService.instance.requestReview();
          await prefs.setHasRated();
        },
        onNotNow: () => Navigator.pop(dialogContext),
      ),
    );
  }

  void _openClassicDifficultyPicker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClassicDifficultyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The score cards below can change from outside this screen entirely
    // (a round played on the gameplay screen, or Settings' "Reset
    // Progress") - watching the revision ticker is what makes this screen
    // actually rebuild for that, since watching the service instance
    // itself doesn't react to writes inside the box it wraps.
    ref.watch(preferencesRevisionProvider);
    final prefs = ref.watch(preferencesServiceProvider);
    final now = DateTime.now();
    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                // Fixed at the top, outside the centered section below - the
                // wordmark header shouldn't drift toward the middle of the
                // screen along with the mode cards.
                Column(
                  children: [
                    const SizedBox(height: 8),
                    const WordmarkIcon(size: 64),
                    const SizedBox(height: 8),
                    Text('NUMBERAMA',
                        style:
                            AppTextStyles.display(36, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('TAP · SUM · CLEAR', style: AppTextStyles.caption),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _PeriodScoreChip(
                                  label: "Today's",
                                  score: prefs.todayBestScore,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PeriodScoreChip(
                                  label: HomeScreen._monthNames[now.month - 1],
                                  score: prefs.monthBestScore,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PeriodScoreChip(
                                  label: '${now.year}',
                                  score: prefs.yearBestScore,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _BestEverCard(score: prefs.bestScore),
                          const SizedBox(height: 18),
                          ModeCard(
                            icon: Icons.grid_view_rounded,
                            iconColor: AppColors.amber,
                            title: 'Classic',
                            description:
                                'Clear the grid before it fills up. No clock, just pressure.',
                            action: GradientButton(
                              label: 'Play Classic',
                              onPressed: () =>
                                  _openClassicDifficultyPicker(context),
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

/// One of the three small best-score chips at the top of the home screen -
/// "Today's", "Month's", "Yearly" - each reading a period-bucketed best
/// from [PreferencesService] (combined across Classic and Daily rounds).
/// Sits above the more prominent all-time [_BestEverCard].
class _PeriodScoreChip extends StatelessWidget {
  const _PeriodScoreChip({required this.label, required this.score});

  final String label;
  final int score;

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
          Text('$score', style: AppTextStyles.mono(17, color: AppColors.amber)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// The all-time high score - [PreferencesService.bestScore] - in its own
/// banner beneath the smaller period chips, since it's the one number here
/// worth calling out above the rest.
class _BestEverCard extends StatelessWidget {
  const _BestEverCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.amber, size: 20),
              const SizedBox(width: 10),
              Text('BEST EVER', style: AppTextStyles.caption),
            ],
          ),
          Text('$score',
              style: AppTextStyles.mono(22, color: AppColors.textHi)),
        ],
      ),
    );
  }
}

/// The automatic "Rate Numberama" prompt - see [_HomeScreenState.
/// _maybeShowRatePrompt] for when this shows. "Not Now" just dismisses (it
/// shows again per the usual cooldown); "Rate Now" is the one path that
/// permanently retires it, via [PreferencesService.setHasRated].
class _RatePromptDialog extends StatelessWidget {
  const _RatePromptDialog({required this.onRate, required this.onNotNow});

  final VoidCallback onRate;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.amber, size: 44),
          const SizedBox(height: 12),
          Text(
            'Enjoying Numberama?',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            "A quick rating helps a lot and takes only a few seconds.",
            textAlign: TextAlign.center,
            style: AppTextStyles.display(13,
                weight: FontWeight.w400, color: AppColors.textMid),
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Rate Now', onPressed: onRate),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNotNow,
              child: const Text('Not Now'),
            ),
          ),
        ],
      ),
    );
  }
}
