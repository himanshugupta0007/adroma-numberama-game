import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberama/game/grid_component.dart';
import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/game/tile_component.dart';
import 'package:numberama/state/game_state.dart';

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

/// Finds two currently-active tiles that would NOT form a valid pair.
List<TileComponent>? _findInvalidPair(List<TileComponent> tiles) {
  for (var i = 0; i < tiles.length; i++) {
    for (var j = i + 1; j < tiles.length; j++) {
      final a = tiles[i];
      final b = tiles[j];
      if (a.value != b.value && a.value + b.value != 10) {
        return [a, b];
      }
    }
  }
  return null;
}

/// Runs enough update ticks for tap/clear/shake/collapse animations
/// (0.25s worst case) to fully settle.
Future<void> _settle(NumberamaGame game) async {
  for (var i = 0; i < 60; i++) {
    game.update(1 / 60);
    await game.ready();
  }
}

/// A stand-in for [NumberamaGame.autoRowIntervalSeconds] in tests that
/// aren't exercising the auto-row timer itself: `_settle` advances the
/// game clock by a full second per call, and tests below call it several
/// times, so a real 5s interval would fire mid-test and desync tile counts
/// from what the test expects. Effectively "never" within a single test run.
const double _noAutoRows = 1e6;

Future<void> _advance(NumberamaGame game, double seconds) async {
  const step = 1 / 60;
  var remaining = seconds;
  while (remaining > 0) {
    game.update(step);
    await game.ready();
    remaining -= step;
  }
}

void main() {
  testWithGame<NumberamaGame>(
    'populates a 9-column grid with 3 initial rows on load',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      expect(game.gridComponent.tileCount, GridComponent.columns * 3);
      expect(game.gameStateNotifier.state.phase, GamePhase.playing);
    },
  );

  testWithGame<NumberamaGame>(
    'tapping a valid pair clears both tiles and scores a point',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      final tiles = game.gridComponent.activeTiles;
      final pair = _findValidPair(tiles);
      expect(pair, isNotNull,
          reason: 'expected at least one valid pair in a 27-tile grid');
      final [tileA, tileB] = pair!;

      final beforeCount = game.gridComponent.tileCount;

      game.selectionManager.onTileTapped(tileA);
      expect(tileA.visualState, TileVisualState.selected);

      game.selectionManager.onTileTapped(tileB);
      await _settle(game);

      expect(game.gridComponent.tileCount, beforeCount - 2);
      expect(game.gameStateNotifier.state.score, 10);
      expect(game.gameStateNotifier.state.moves, 1);
    },
  );

  testWithGame<NumberamaGame>(
    'tapping an invalid pair shakes and deselects without scoring',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      final tiles = game.gridComponent.activeTiles;
      final pair = _findInvalidPair(tiles);
      expect(pair, isNotNull,
          reason: 'expected at least one invalid pair in a 27-tile grid');
      final [tileA, tileB] = pair!;

      final beforeCount = game.gridComponent.tileCount;

      game.selectionManager.onTileTapped(tileA);
      game.selectionManager.onTileTapped(tileB);
      await _settle(game);

      expect(game.gridComponent.tileCount, beforeCount);
      expect(game.gameStateNotifier.state.score, 0);
      expect(game.gameStateNotifier.state.moves, 0);
      expect(tileA.visualState, TileVisualState.idle);
      expect(tileB.visualState, TileVisualState.idle);
    },
  );

  testWithGame<NumberamaGame>(
    'addRow appends 9 more tiles',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();
      final before = game.gridComponent.tileCount;

      game.gridComponent.addRow();
      await game.ready();

      expect(game.gridComponent.tileCount, before + GridComponent.columns);
    },
  );

  testWithGame<NumberamaGame>(
    'clearing the whole board sets phase to won',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(5),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      var safetyCounter = 0;
      while (!game.gridComponent.isEmpty && safetyCounter < 500) {
        safetyCounter++;
        final pair = _findValidPair(game.gridComponent.activeTiles);
        if (pair == null) break;
        final [tileA, tileB] = pair;
        game.selectionManager.onTileTapped(tileA);
        game.selectionManager.onTileTapped(tileB);
        await _settle(game);
      }

      expect(game.gridComponent.isEmpty, isTrue);
      expect(game.gameStateNotifier.state.phase, GamePhase.won);
    },
  );

  testWithGame<NumberamaGame>(
    'initial rows land on distinct, non-overlapping slots',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      // Regression check: the initial fill used to queue an animated
      // MoveEffect per addRow() call with no frame tick in between, so a
      // still-pending effect from row 2's shift got clobbered by row 3's -
      // rows could end up sharing a y (row 3 rendered on top of row 2).
      final rowYs = game.gridComponent.activeTiles
          .map((tile) => tile.position.y)
          .toSet();
      expect(rowYs.length, NumberamaGame.initialRows,
          reason: 'each of the ${NumberamaGame.initialRows} initial rows '
              'should occupy a distinct row slot, not overlap another row');
    },
  );

  testWithGame<NumberamaGame>(
    'the board is a fixed 9x9 square that fits the canvas without overflowing',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      // Square on purpose: columns == maxRows means cell size is bound by
      // min(width, height) equally on both axes, so the board shrinks or
      // grows uniformly on any screen instead of needing extra vertical
      // room that could force the page to scroll.
      expect(GridComponent.columns, GridComponent.maxRows);

      // A tile's rendered size reveals the cell size actually chosen, so
      // we can confirm the full rectangle it implies still fits inside the
      // canvas rather than clipping off an edge.
      final tileSize = game.gridComponent.activeTiles.first.size.y;
      const paddingFactor = 0.1;
      final cellSize = tileSize / (1 - paddingFactor);
      final boardWidth = GridComponent.columns * cellSize;
      final boardHeight = GridComponent.maxRows * cellSize;

      expect(boardWidth, lessThanOrEqualTo(game.size.x + 0.01));
      expect(boardHeight, lessThanOrEqualTo(game.size.y + 0.01));
    },
  );

  testWithGame<NumberamaGame>(
    'a row automatically rises from the bottom once the interval elapses',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: 0.5),
    (game) async {
      await game.ready();
      final before = game.gridComponent.tileCount;

      await _advance(game, 0.5);

      expect(game.gridComponent.tileCount, before + GridComponent.columns);
      expect(game.gameStateNotifier.state.phase, GamePhase.playing);
    },
  );

  testWithGame<NumberamaGame>(
    'the round ends the moment the rising stack has no room left at the top',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: 0.5),
    (game) async {
      await game.ready();

      while (game.gridComponent.canAddRow) {
        game.gridComponent.addRow();
      }
      await game.ready();

      await _advance(game, 0.5);

      expect(game.gameStateNotifier.state.phase, GamePhase.lost);
    },
  );
}
