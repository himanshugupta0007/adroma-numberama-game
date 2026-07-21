import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/numberama_game.dart';
import '../../state/game_mode.dart';
import '../../state/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/graph_paper_background.dart';
import '../results/results_screen.dart';
import 'power_bar.dart';
import 'sum_arc_overlay.dart';

/// The core play screen: HUD chrome (top bar, score row, power bar)
/// wrapped around the real [NumberamaGame] canvas. Owns exactly one
/// [NumberamaGame] instance for its lifetime, created once in [initState]
/// so score/phase updates (via Riverpod) never reconstruct the Flame game -
/// only narrowly-scoped HUD subtrees rebuild on state change.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key, required this.mode});

  final GameMode mode;

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
    _game = NumberamaGame(gameStateNotifier: notifier);
  }

  void _goToResults(GameState state, {required bool won}) {
    if (_navigatedToResults) return;
    _navigatedToResults = true;
    final score = state.score;
    final pairs = state.moves;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            score: score,
            pairs: pairs,
            mode: widget.mode,
            won: won,
          ),
        ),
      );
    });
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

    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _TopBar(mode: widget.mode),
                const SizedBox(height: 16),
                const _ScoreRow(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                const SizedBox(height: 16),
                const PowerBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textHi),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            mode.pillLabel,
            style: AppTextStyles.mono(11,
                weight: FontWeight.w600, color: AppColors.textMid),
          ),
        ),
        // Inert this pass - no pause/menu behavior implemented yet.
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.pause_rounded, color: AppColors.textHi),
        ),
      ],
    );
  }
}

class _ScoreRow extends ConsumerWidget {
  const _ScoreRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(gameStateProvider.select((s) => s.score));

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
        // TODO(combo): no combo/streak tracking exists yet - static.
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
              Text('x1', style: AppTextStyles.mono(11, color: AppColors.amber)),
            ],
          ),
        ),
        // TODO(best-score): no persistence layer yet - honest placeholder.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('—',
                style: AppTextStyles.mono(16, color: AppColors.textLow)),
            Text('BEST', style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}
