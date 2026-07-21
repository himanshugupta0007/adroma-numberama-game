import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/game/tile_component.dart';
import 'package:numberama/main.dart';
import 'package:numberama/state/game_state.dart';
import 'package:numberama/ui/results/results_screen.dart';
import 'package:numberama/widgets/gradient_button.dart';

/// Finds two currently-active tiles that would form a valid pair (equal
/// value, or summing to 10), if any exist.
List<TileComponent>? _findValidPair(List<TileComponent> tiles) {
  for (var i = 0; i < tiles.length; i++) {
    for (var j = i + 1; j < tiles.length; j++) {
      final a = tiles[i];
      final b = tiles[j];
      if (a.value == b.value || a.value + b.value == 10) {
        return [a, b];
      }
    }
  }
  return null;
}

// FlameGame's internal ticker schedules a new frame every frame once a
// GameWidget is live, so `pumpAndSettle` never settles from this point on -
// pump a bounded number of frames instead. This also drives Flame's own
// lifecycle processing (mounting components, running onLoad chains), so
// `game.ready()` is deliberately never awaited here: its internal loop
// yields via `Future.delayed(Duration.zero)`, which never fires under
// flutter_test's fake-async clock unless something concurrently pumps it -
// awaiting it bare inside a plain `testWidgets` hangs forever.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Navigates from Home to a real Gameplay round and returns the live game
/// plus its provider container.
Future<(NumberamaGame, ProviderContainer)> _openGameplay(
    WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NumberamaApp()));
  await tester.pumpAndSettle();

  final playClassicButton = find.widgetWithText(GradientButton, 'Play Classic');
  await tester.ensureVisible(playClassicButton);
  await tester.pump();
  await tester.tap(playClassicButton);
  // Bounded pumps for the route transition and for Flame to finish its
  // onLoad chain (grid built, initial rows added) - not pumpAndSettle, the
  // new screen's GameWidget starts ticking continuously immediately.
  await _pumpFrames(tester, frames: 60);

  final game = tester
      .widget<GameWidget<NumberamaGame>>(find.byType(GameWidget<NumberamaGame>))
      .game!;

  final container = ProviderScope.containerOf(
    tester.element(find.byType(GameWidget<NumberamaGame>)),
  );
  return (game, container);
}

void main() {
  testWidgets(
      'Home -> Play Classic reaches a real, playable grid without '
      'reconstructing the game on state changes', (tester) async {
    final (game, container) = await _openGameplay(tester);
    expect(container.read(gameStateProvider).score, 0);

    final tiles = game.gridComponent.activeTiles;
    final pair = _findValidPair(tiles);
    expect(pair, isNotNull,
        reason: 'expected at least one valid pair in a fresh 24-tile grid');
    final [tileA, tileB] = pair!;

    game.selectionManager.onTileTapped(tileA);
    game.selectionManager.onTileTapped(tileB);
    await _pumpFrames(tester);

    expect(container.read(gameStateProvider).score, 10);
    expect(container.read(gameStateProvider).moves, 1);
    // Same GameWidget/game instance persisted across the score update -
    // proves the Riverpod rebuild-safety pattern in GameplayScreen holds.
    expect(
      tester
          .widget<GameWidget<NumberamaGame>>(find.byType(GameWidget<NumberamaGame>))
          .game,
      same(game),
    );
  });

  // Clearing an entire (now up to 8-row) board via repeated real taps is
  // already covered deterministically and quickly by
  // test/game/numberama_game_test.dart. These two tests instead target
  // what's new here: GameplayScreen's reaction to phase changes and
  // ResultsScreen's won/lost rendering - so they drive one real pair (to
  // prove score/pairs flow through), then force the phase transition
  // directly rather than re-simulating a full board clear.
  testWidgets(
      'winning a round navigates to ResultsScreen with the real score/pairs',
      (tester) async {
    final (game, container) = await _openGameplay(tester);

    final pair = _findValidPair(game.gridComponent.activeTiles);
    expect(pair, isNotNull);
    final [tileA, tileB] = pair!;
    game.selectionManager.onTileTapped(tileA);
    game.selectionManager.onTileTapped(tileB);
    await _pumpFrames(tester);
    expect(container.read(gameStateProvider).score, 10);
    expect(container.read(gameStateProvider).moves, 1);

    container.read(gameStateProvider.notifier).setPhase(GamePhase.won);
    // Let the post-frame navigation callback (GamePhase.won -> Results)
    // fire and the route transition complete.
    await _pumpFrames(tester, frames: 40);

    expect(find.byType(ResultsScreen), findsOneWidget);
    final results = tester.widget<ResultsScreen>(find.byType(ResultsScreen));
    expect(results.won, isTrue);
    expect(results.score, 10);
    expect(results.pairs, 1);
    expect(find.text('ROUND COMPLETE'), findsOneWidget);
  });

  testWidgets(
      'board full while stuck navigates to ResultsScreen as a loss',
      (tester) async {
    final (game, container) = await _openGameplay(tester);
    expect(game.gridComponent.canAddRow, isTrue);

    container.read(gameStateProvider.notifier).setPhase(GamePhase.lost);
    await _pumpFrames(tester, frames: 40);

    expect(find.byType(ResultsScreen), findsOneWidget);
    final results = tester.widget<ResultsScreen>(find.byType(ResultsScreen));
    expect(results.won, isFalse);
    expect(find.text('BOARD FULL'), findsOneWidget);
    expect(find.text('NO MORE ROOM'), findsOneWidget);
  });
}
