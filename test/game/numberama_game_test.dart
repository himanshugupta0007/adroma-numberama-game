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

void main() {
  testWithGame<NumberamaGame>(
    'populates a 9-column grid with 3 initial rows on load',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(), random: Random(1)),
    (game) async {
      await game.ready();

      expect(game.gridComponent.tileCount, GridComponent.columns * 3);
      expect(game.gameStateNotifier.state.phase, GamePhase.playing);
    },
  );

  testWithGame<NumberamaGame>(
    'tapping a valid pair clears both tiles and scores a point',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(), random: Random(1)),
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
        gameStateNotifier: GameStateNotifier(), random: Random(1)),
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
        gameStateNotifier: GameStateNotifier(), random: Random(1)),
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
        gameStateNotifier: GameStateNotifier(), random: Random(7)),
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
}
