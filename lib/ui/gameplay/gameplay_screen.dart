import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/numberama_game.dart';
import '../../services/notification_service.dart';
import '../../state/difficulty.dart';
import '../../state/game_mode.dart';
import '../../state/game_state.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/dialog_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/graph_paper_background.dart';
import '../results/results_screen.dart';
import 'how_to_play_dialog.dart';
import 'power_bar.dart';
import 'sum_arc_overlay.dart';

/// The core play screen: HUD chrome (top bar, score row, power bar)
/// wrapped around the real [NumberamaGame] canvas. Owns exactly one
/// [NumberamaGame] instance for its lifetime, created once in [initState]
/// so score/phase updates (via Riverpod) never reconstruct the Flame game -
/// only narrowly-scoped HUD subtrees rebuild on state change.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({
    super.key,
    required this.mode,
    this.difficulty = Difficulty.medium,
    this.isDaily = false,
  });

  final GameMode mode;

  /// Only varies for the Daily Challenge - Classic/Rush from the home
  /// screen always play at [Difficulty.medium].
  final Difficulty difficulty;

  /// Whether this round is today's Daily Challenge board rather than an
  /// ordinary Classic/Rush round - changes the top bar's pill, gates a
  /// replay to one attempt per day, and switches the results screen over
  /// to a star rating instead of "Play again".
  final bool isDaily;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  late final NumberamaGame _game;
  bool _navigatedToResults = false;

  @override
  void initState() {
    super.initState();
    // Riverpod forbids modifying a provider during a widget lifecycle
    // method (initState included) - no explicit reset() needed here
    // anyway, since NumberamaGame.onLoad() already calls
    // gameStateNotifier.startGame(), which fully resets score/moves/phase
    // and runs safely outside Flutter's build phase (it's Flame's own
    // async lifecycle, not a widget one).
    final notifier = ref.read(gameStateProvider.notifier);
    _game = NumberamaGame(
      gameStateNotifier: notifier,
      difficulty: widget.difficulty,
      isDaily: widget.isDaily,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowHowToPlay());
  }

  /// Auto-shows the rules dialog the first time a player ever reaches this
  /// screen. Runs after the first frame (not synchronously in [initState])
  /// so `showDialog` has a [Navigator] to find, and marks the flag
  /// immediately rather than waiting on the dialog's dismissal - a player
  /// who kills the app mid-dialog shouldn't see it forced on them again.
  void _maybeShowHowToPlay() {
    if (!mounted) return;
    final prefs = ref.read(preferencesServiceProvider);
    if (prefs.hasSeenHowToPlay) return;
    prefs.setHasSeenHowToPlay();
    _showHowToPlay();
  }

  /// Shows the "How to Play" rules, pausing the round behind it - reused by
  /// both the first-time auto-show and the top bar's "?" button, so
  /// reviewing the rules mid-round doesn't let the auto-row timer or a
  /// stray tap keep advancing the game underneath the dialog.
  Future<void> _showHowToPlay() async {
    _game.pauseEngine();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => HowToPlayDialog(
        onDismiss: () => Navigator.pop(dialogContext),
      ),
    );
    _game.resumeEngine();
  }

  void _goToResults(GameState state, {required bool won}) {
    if (_navigatedToResults) return;
    _navigatedToResults = true;
    final score = state.score;
    final pairs = state.moves;
    final bestCombo = state.bestCombo;

    // A new best counts on a loss too (a high score before getting stuck is
    // still a real achievement) - computed synchronously against the box's
    // current value, then persisted; nothing else touches the box between
    // these two lines, so the comparison can't go stale.
    final prefs = ref.read(preferencesServiceProvider);
    final isNewBest = score > prefs.bestScore;
    if (isNewBest) prefs.registerScore(score);

    if (widget.isDaily) {
      // Win or loss, today's one attempt is spent - there's no board-state
      // persistence to let a player resume an abandoned round anyway, and
      // gating on completion (not on tapping "Start") means backing out of
      // the pre-round dialogs doesn't cost an attempt.
      prefs.registerDailyPlayed(DateTime.now());
      // Today's board is done either way (win or loss) - don't nag about a
      // streak the player already kept alive today, but leave tomorrow's
      // reminder untouched.
      ref.read(notificationServiceProvider).skipTodaysReminder();
    }
    final dailyStars = widget.isDaily ? _starsForDaily(bestCombo, won: won) : 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            score: score,
            pairs: pairs,
            bestCombo: bestCombo,
            isNewBest: isNewBest,
            mode: widget.mode,
            won: won,
            isDaily: widget.isDaily,
            difficulty: widget.difficulty,
            dailyStars: dailyStars,
          ),
        ),
      );
    });
  }

  /// A simple, tunable heuristic for the Daily Challenge's star rating: 0
  /// on a loss, otherwise 1 star just for clearing the board plus one more
  /// for each combo-streak threshold reached. Scales naturally with
  /// difficulty since Hard's missing power-ups and far-apart pair
  /// placement make a long combo harder to sustain in the first place - no
  /// separate per-tier thresholds needed.
  int _starsForDaily(int bestCombo, {required bool won}) {
    if (!won) return 0;
    var stars = 1;
    if (bestCombo >= 3) stars++;
    if (bestCombo >= 6) stars++;
    return stars;
  }

  /// Shows the leave-confirmation dialog and, if the player confirms, pops
  /// this screen. Returns whether the screen was actually left, so the
  /// [PopScope] below can report back on the pop attempt it intercepted.
  Future<bool> _confirmExit() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Leave game?',
        message: "You'll lose your current progress.",
        confirmLabel: 'Leave',
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.pop(context);
      return true;
    }
    return false;
  }

  /// Pauses the Flame game loop - tile taps, tile animations, and the
  /// auto-row timer all only advance via `update()`, so this alone freezes
  /// the whole round - then blocks interaction behind a dialog until the
  /// player resumes.
  Future<void> _pause() async {
    _game.pauseEngine();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PauseDialog(
        onResume: () => Navigator.pop(dialogContext),
      ),
    );
    _game.resumeEngine();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameStateProvider, (previous, next) {
      if (next.phase == GamePhase.won) _goToResults(next, won: true);
      // Reached whenever the rising stack has nowhere left to go: either
      // the 5s auto-row timer or the stuck-board safety net in
      // SelectionManager tried to add a row past GridComponent.maxRows,
      // i.e. a tile would have hit the rectangle's top edge.
      if (next.phase == GamePhase.lost) _goToResults(next, won: false);
    });

    return PopScope(
      // Always intercepted (system back gesture/button included) so
      // leaving mid-round always goes through the same confirmation as the
      // top bar's back button - see _confirmExit.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        body: GraphPaperBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  _TopBar(
                    pillLabel: widget.isDaily
                        ? 'Daily · ${widget.difficulty.label}'
                        : widget.mode.pillLabel,
                    onBack: _confirmExit,
                    onHelp: _showHowToPlay,
                    onPause: _pause,
                  ),
                  const SizedBox(height: 16),
                  _ScoreRow(isDaily: widget.isDaily),
                  Expanded(
                    child: Padding(
                      // Symmetric on purpose: keeps the board equidistant
                      // from the score row above and the power bar below on
                      // every screen height, rather than one gap silently
                      // ending up bigger than the other.
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Stack(
                        children: [
                          Positioned.fill(child: GameWidget(game: _game)),
                          Positioned.fill(
                            child: SumArcOverlay(
                              selectionManager: _game.selectionManager,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PowerBar(selectionManager: _game.selectionManager),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pillLabel,
    required this.onBack,
    required this.onHelp,
    required this.onPause,
  });

  final String pillLabel;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CircleIconButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onBack,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            pillLabel,
            style: AppTextStyles.mono(16,
                weight: FontWeight.w600, color: AppColors.textMid),
          ),
        ),
        Row(
          children: [
            _CircleIconButton(
              icon: Icons.help_outline_rounded,
              onPressed: onHelp,
            ),
            const SizedBox(width: 8),
            _CircleIconButton(
              icon: Icons.pause_rounded,
              onPressed: onPause,
            ),
          ],
        ),
      ],
    );
  }
}

/// A solid amber badge behind an icon. Plain icons render directly on
/// [GraphPaperBackground], whose faint grid lines don't give `textHi` icons
/// enough contrast to read clearly - the circle gives both the back and
/// pause controls a solid backdrop instead.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  static const _diameter = 40.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: _diameter,
          height: _diameter,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.amber,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.onAmber, size: 20),
        ),
      ),
    );
  }
}

class _ScoreRow extends ConsumerWidget {
  const _ScoreRow({required this.isDaily});

  /// Swaps the all-time "BEST" score readout for a live Rush countdown -
  /// the best score isn't very interesting mid-sprint, and the countdown
  /// is the one thing a Daily round has that Classic doesn't.
  final bool isDaily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(gameStateProvider.select((s) => s.score));
    final combo = ref.watch(gameStateProvider.select((s) => s.combo));
    final bestScore = ref.watch(preferencesServiceProvider).bestScore;
    final rushSecondsRemaining =
        ref.watch(gameStateProvider.select((s) => s.rushSecondsRemaining));
    // No streak yet (start of round / just missed a pair) still reads as
    // "x1" rather than "x0" - it's the multiplier the *next* pair would
    // earn, not a count of pairs already cleared.
    final comboMultiplier = combo == 0 ? 1 : combo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$score', style: AppTextStyles.scoreDisplay),
            Text('SCORE', style: AppTextStyles.caption),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 11, color: AppColors.amber),
              const SizedBox(width: 4),
              Text('x$comboMultiplier',
                  style: AppTextStyles.mono(11, color: AppColors.amber)),
            ],
          ),
        ),
        if (isDaily)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatCountdown(rushSecondsRemaining ?? 0),
                  style: AppTextStyles.mono(16, color: AppColors.coral)),
              Text('TIME', style: AppTextStyles.caption),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$bestScore',
                  style: AppTextStyles.mono(16, color: AppColors.textHi)),
              Text('BEST', style: AppTextStyles.caption),
            ],
          ),
      ],
    );
  }

  String _formatCountdown(int totalSeconds) {
    final clamped = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = clamped ~/ 60;
    final seconds = clamped % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(13,
                weight: FontWeight.w400, color: AppColors.textMid),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  // Amber, not a "destructive" red - the app has one accent
                  // color for every primary action (GradientButton, the
                  // back/pause badges, ...) and this dialog's primary
                  // action is no exception.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.onAmber,
                    side: BorderSide.none,
                  ),
                  onPressed: onConfirm,
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PauseDialog extends StatelessWidget {
  const _PauseDialog({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_filled_rounded,
              color: AppColors.amber, size: 48),
          const SizedBox(height: 12),
          Text('Paused', style: AppTextStyles.display(20, weight: FontWeight.w700)),
          const SizedBox(height: 20),
          GradientButton(label: 'Resume', onPressed: onResume),
        ],
      ),
    );
  }
}
