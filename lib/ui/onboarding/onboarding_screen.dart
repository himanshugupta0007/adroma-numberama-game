import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/demo_tile.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../home/home_screen.dart';

/// Three-slide animated walkthrough of the one rule the whole game hinges
/// on (tap a matching pair) plus the win condition, shown full-screen
/// before [HomeScreen] on a player's very first launch - see
/// [PreferencesService.hasSeenOnboarding].
///
/// Also reachable on demand from Settings ("Replay Tutorial") via
/// [isReplay], which changes how the final step exits: a first-launch
/// viewing replaces itself with [HomeScreen] (there's nothing to go back
/// to), a replay just pops back to Settings.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.isReplay = false});

  final bool isReplay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(preferencesServiceProvider).setHasSeenOnboarding();
    if (!mounted) return;
    if (widget.isReplay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _handleNext() {
    if (_page == _pageCount - 1) {
      _finish();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;
    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _SkipButton(onTap: _finish),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [
                    _OnboardingPage(
                      title: 'Match Same Numbers',
                      body: 'Tap two tiles showing the same number to '
                          'clear them.',
                      animation: _PairMatchAnimation(valueA: 7, valueB: 7),
                    ),
                    _OnboardingPage(
                      title: 'Or Make a 10',
                      body: 'Two tiles that add up to 10 - like 4 and 6 -'
                          ' clear too.',
                      animation: _PairMatchAnimation(
                        valueA: 4,
                        valueB: 6,
                        sumBadge: '4 + 6 = 10',
                      ),
                    ),
                    _OnboardingPage(
                      title: 'Clear It Before It Reaches the Top',
                      body: 'New rows keep rising. Clear tiles faster than '
                          'the stack grows to win the round.',
                      animation: _ClearBoardAnimation(),
                    ),
                  ],
                ),
              ),
              _PageDots(count: _pageCount, current: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: isLast ? "Let's Play" : 'Next',
                    onPressed: _handleNext,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            'Skip',
            style: AppTextStyles.display(
              13,
              weight: FontWeight.w600,
              color: AppColors.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.amber : AppColors.textLow,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.animation,
  });

  final String title;
  final String body;
  final Widget animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 200, child: Center(child: animation)),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(22, weight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              14,
              weight: FontWeight.w400,
              color: AppColors.textMid,
            ),
          ),
        ),
      ],
    );
  }
}

/// Returns how far `t` has progressed through the `[start, end)` window, as
/// 0-1 - 0 before it starts, 1 once it's past. Used instead of nested
/// [CurvedAnimation]/[Interval] objects to keep each looping demo's whole
/// timeline readable as a flat sequence of (start, end) windows.
double _windowProgress(double t, double start, double end) {
  if (t <= start) return 0;
  if (t >= end) return 1;
  return (t - start) / (end - start);
}

/// Loops forever: two tiles slide together, flash as "selected", then pop
/// and fade out as a cleared pair - the one gesture the whole game is built
/// on. [sumBadge], when set, fades in alongside the selected flash to spell
/// out why the pair matched (used for the "sum to 10" slide).
class _PairMatchAnimation extends StatefulWidget {
  const _PairMatchAnimation({
    required this.valueA,
    required this.valueB,
    this.sumBadge,
  });

  final int valueA;
  final int valueB;
  final String? sumBadge;

  @override
  State<_PairMatchAnimation> createState() => _PairMatchAnimationState();
}

class _PairMatchAnimationState extends State<_PairMatchAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tileSize = 64.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final slideT = Curves.easeOut.transform(_windowProgress(t, 0, 0.35));
        final gap = lerpDouble(56, 10, slideT)!;
        final selected = t >= 0.35 && t < 0.78;
        final clearT = Curves.easeIn.transform(_windowProgress(t, 0.78, 0.95));
        final scale = lerpDouble(1, 0, clearT)!;
        final badgeT = Curves.easeOut.transform(_windowProgress(t, 0.42, 0.6));
        final badgeFadeOut =
            1 - Curves.easeIn.transform(_windowProgress(t, 0.72, 0.82));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: widget.sumBadge == null
                  ? null
                  : Opacity(
                      opacity: badgeT * badgeFadeOut,
                      child: Text(
                        widget.sumBadge!,
                        style: AppTextStyles.mono(13, color: AppColors.teal),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: scale,
                  child: DemoTile(
                    value: widget.valueA,
                    size: tileSize,
                    selected: selected,
                  ),
                ),
                SizedBox(width: gap),
                Transform.scale(
                  scale: scale,
                  child: DemoTile(
                    value: widget.valueB,
                    size: tileSize,
                    selected: selected,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Loops forever: a small board of tiles clears pair by pair down to
/// nothing, then holds briefly on a "CLEARED!" badge before resetting -
/// illustrating the win condition (clear the board) without implying any
/// one correct clearing order.
class _ClearBoardAnimation extends StatefulWidget {
  const _ClearBoardAnimation();

  @override
  State<_ClearBoardAnimation> createState() => _ClearBoardAnimationState();
}

class _ClearBoardAnimationState extends State<_ClearBoardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 3 rows x 4 columns, cleared in 6 same-value pairs - values don't need
  // to reflect real board generation, just read as plausible matches.
  static const _values = [
    [5, 5, 3, 7],
    [8, 2, 9, 1],
    [6, 4, 4, 6],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tileSize = 32.0;
    const spacing = 6.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final badgeT = Curves.easeOut.transform(_windowProgress(t, 0.86, 0.95));
        final badgeFadeOut =
            1 - Curves.easeIn.transform(_windowProgress(t, 0.98, 1));

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              child: Opacity(
                opacity: badgeT * badgeFadeOut,
                child: Text(
                  'CLEARED!',
                  style: AppTextStyles.mono(13, color: AppColors.teal),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var row = 0; row < _values.length; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: spacing),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var col = 0; col < _values[row].length; col++)
                      Padding(
                        padding: const EdgeInsets.only(right: spacing),
                        child: _buildTile(row, col, t, tileSize),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTile(int row, int col, double t, double tileSize) {
    // Each of the 12 tiles gets its own short clear window, staggered
    // across the first ~80% of the timeline, left-to-right/top-to-bottom.
    final index = row * _values[row].length + col;
    final start = 0.05 + index * 0.06;
    final clearT =
        Curves.easeIn.transform(_windowProgress(t, start, start + 0.12));
    return Transform.scale(
      scale: lerpDouble(1, 0, clearT)!,
      child: DemoTile(value: _values[row][col], size: tileSize),
    );
  }
}
