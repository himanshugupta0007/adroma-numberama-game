import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numberama/game/grid_component.dart';
import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/game/tile_component.dart';
import 'package:numberama/state/difficulty.dart';
import 'package:numberama/state/game_state.dart';

/// AudioService (played on every match/mismatch/power-up) reaches for a
/// real platform channel the very first time it's touched. Without a
/// binding + a mocked handler for it, that first call throws synchronously
/// out of whatever triggered it (e.g. a valid-pair tap), which can abort
/// the test before its own assertions even run - not something any
/// individual test should have to work around itself.
void _mockAudioPlatformChannels() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final name in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
}

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
  _mockAudioPlatformChannels();

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
      expect(rowYs.length, game.initialRows,
          reason: 'each of the ${game.initialRows} initial rows should '
              'occupy a distinct row slot, not overlap another row');
    },
  );

  testWithGame<NumberamaGame>(
    'the board is a fixed 9x8 rectangle that fits the canvas without overflowing',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      // A tile's rendered size reveals the cell size actually chosen, so
      // we can confirm the full rectangle it implies still fits inside the
      // canvas rather than clipping off an edge.
      final tileSize = game.gridComponent.activeTiles.first.size.y;
      const paddingFactor = 0.06;
      final cellSize = tileSize / (1 - paddingFactor);
      final boardWidth = GridComponent.columns * cellSize;
      final boardHeight = game.gridComponent.maxRows * cellSize;

      expect(boardWidth, lessThanOrEqualTo(game.size.x + 0.01));
      expect(boardHeight, lessThanOrEqualTo(game.size.y + 0.01));
    },
  );

  testWithGame<NumberamaGame>(
    'tiles already on the board are resized (not just repositioned) when '
    'the canvas is resized after load',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();
      // .clone() - `size` is a live NotifyingVector2 that the fix below
      // mutates in place, so a plain reference would silently track the
      // post-resize value too and this comparison would trivially pass.
      final sizeBeforeResize = game.gridComponent.activeTiles.first.size.clone();

      // Shrink the canvas well below its original size - since cell size is
      // derived from the canvas (see GridComponent._recalculateMetrics),
      // every tile's target size shrinks too.
      game.onGameResize(game.size / 2);
      await game.ready();

      for (final tile in game.gridComponent.activeTiles) {
        expect(tile.size, isNot(sizeBeforeResize),
            reason: 'every already-placed tile should pick up the new '
                '(smaller) cell size on resize, not just tiles created '
                'afterward - a stale size here is what makes tiles visibly '
                'overlap their neighbors until they happen to get cleared '
                'and replaced');
      }
    },
  );

  testWithGame<NumberamaGame>(
    'a short bottom row left by a collapse lingers until the next addRow(), '
    'which tops it up AND appends a genuinely new full row on top of that',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(3),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();
      // A couple of extra rows so the board has more than one row of tiles
      // to clear a pair out of - a single-row board can never end up short
      // (clearing its only row just wins the round).
      game.gridComponent.addRow(animate: false);
      game.gridComponent.addRow(animate: false);

      final pair = _findValidPair(game.gridComponent.activeTiles);
      expect(pair, isNotNull);
      final [tileA, tileB] = pair!;
      game.selectionManager.onTileTapped(tileA);
      game.selectionManager.onTileTapped(tileB);
      await _settle(game);

      final afterMatch = game.gridComponent.tileCount;
      final shortfall = (GridComponent.columns -
              afterMatch % GridComponent.columns) %
          GridComponent.columns;
      expect(
        shortfall,
        greaterThan(0),
        reason: 'a single match out of a 27-tile board should always leave '
            'the bottom row short by construction (27 is a multiple of 9, '
            'and only 2 tiles were removed) - this is what the rest of the '
            'test actually exercises. A gap should still be lingering here, '
            'not already topped up - an immediate top-up on every match '
            'would refund tiles almost as fast as they clear, making '
            "Classic's win condition practically unreachable.",
      );

      game.gridComponent.addRow();
      await _settle(game);

      expect(
        game.gridComponent.tileCount,
        afterMatch + shortfall + GridComponent.columns,
        reason: 'addRow() should both top the lingering short row back up '
            'to a full row AND append a genuinely new full row underneath - '
            'not just one or the other',
      );
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

  testWithGame<NumberamaGame>(
    'every difficulty generates tile values from the same 1-10 range',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        difficulty: Difficulty.easy,
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      expect(game.initialRows, Difficulty.easy.initialRows);
      for (final tile in game.gridComponent.activeTiles) {
        expect(tile.value, inInclusiveRange(1, 10));
      }
    },
  );

  testWithGame<NumberamaGame>(
    'hard difficulty starts with both power-ups already ad-gated',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        difficulty: Difficulty.hard,
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();

      expect(game.initialRows, Difficulty.hard.initialRows);
      expect(game.gameStateNotifier.state.shuffleAvailable, isFalse);
      expect(game.gameStateNotifier.state.hintAvailable, isFalse);
    },
  );

  testWithGame<NumberamaGame>(
    'Classic rounds have no rush countdown',
    () => NumberamaGame(
        gameStateNotifier: GameStateNotifier(),
        random: Random(1),
        autoRowIntervalSeconds: _noAutoRows),
    (game) async {
      await game.ready();
      expect(game.gameStateNotifier.state.rushSecondsRemaining, isNull);
    },
  );

  group('Daily Challenge Rush', () {
    testWithGame<NumberamaGame>(
      'fills the entire board at load, since its cell count is even',
      () => NumberamaGame(
          gameStateNotifier: GameStateNotifier(),
          isDaily: true,
          random: Random(1),
          rushDuration: const Duration(seconds: 60)),
      (game) async {
        await game.ready();

        expect(
          game.gridComponent.tileCount,
          GridComponent.columns * game.gridComponent.maxRows,
        );
        // Rush is a fixed board, not a rising stack - it starts full.
        expect(game.gridComponent.canAddRow, isFalse);
      },
    );

    testWithGame<NumberamaGame>(
      'is always fully clearable, whichever valid pair is tapped first',
      () => NumberamaGame(
          gameStateNotifier: GameStateNotifier(),
          isDaily: true,
          random: Random(2),
          rushDuration: const Duration(seconds: 60)),
      (game) async {
        await game.ready();

        var safetyCounter = 0;
        while (!game.gridComponent.isEmpty && safetyCounter < 500) {
          safetyCounter++;
          final pair = _findValidPair(game.gridComponent.activeTiles);
          // Every planted pair sits entirely within one "value component"
          // ({1,9}, {2,8}, {3,7}, {4,6}, {5}) where any two members are
          // mutually valid, and every clear removes exactly two tiles from
          // whichever component they came from - so no component can ever
          // reach an odd remaining count, and the board can never truly
          // get stuck with tiles left, regardless of clear order.
          expect(pair, isNotNull,
              reason: 'Rush board should never get stuck with tiles left');
          final [tileA, tileB] = pair!;
          game.selectionManager.onTileTapped(tileA);
          game.selectionManager.onTileTapped(tileB);
          await _settle(game);
        }

        expect(game.gridComponent.isEmpty, isTrue);
      },
    );

    testWithGame<NumberamaGame>(
      'ends in a win if the board clears before the countdown runs out',
      () => NumberamaGame(
          gameStateNotifier: GameStateNotifier(),
          isDaily: true,
          random: Random(2),
          rushDuration: const Duration(seconds: 60)),
      (game) async {
        await game.ready();

        var safetyCounter = 0;
        while (!game.gridComponent.isEmpty && safetyCounter < 500) {
          safetyCounter++;
          final pair = _findValidPair(game.gridComponent.activeTiles);
          expect(pair, isNotNull);
          final [tileA, tileB] = pair!;
          game.selectionManager.onTileTapped(tileA);
          game.selectionManager.onTileTapped(tileB);
          await _settle(game);
        }

        expect(game.gridComponent.isEmpty, isTrue);
        expect(game.gameStateNotifier.state.phase, GamePhase.won);
      },
    );

    testWithGame<NumberamaGame>(
      'ends in a loss the moment the countdown reaches zero with tiles left',
      () => NumberamaGame(
          gameStateNotifier: GameStateNotifier(),
          isDaily: true,
          random: Random(1),
          rushDuration: const Duration(seconds: 2)),
      (game) async {
        await game.ready();
        expect(game.gridComponent.isEmpty, isFalse);

        await _advance(game, 2);

        expect(game.gameStateNotifier.state.phase, GamePhase.lost);
      },
    );

    testWithGame<NumberamaGame>(
      'does not end early just because the board looks stuck - only the '
      'clock can end it before a clear', () => NumberamaGame(
          gameStateNotifier: GameStateNotifier(),
          isDaily: true,
          random: Random(1),
          rushDuration: const Duration(seconds: 5)),
      (game) async {
        await game.ready();
        // Rush fills every row - there's no rising-stack "room" to refill,
        // so if Classic's stuck-refill/auto-lose logic somehow still ran
        // here, the round would end the instant it judged the board stuck.
        // Letting time pass with no taps at all must never end the round
        // before the clock does.
        expect(game.gridComponent.canAddRow, isFalse);

        await _advance(game, 3);

        expect(game.gameStateNotifier.state.phase, GamePhase.playing);
      },
    );

    testWithGame<NumberamaGame>(
      'the countdown ticks down once a second and is mirrored into GameState',
      () => NumberamaGame(
          gameStateNotifier: GameStateNotifier(),
          isDaily: true,
          random: Random(1),
          rushDuration: const Duration(seconds: 10)),
      (game) async {
        await game.ready();
        expect(game.gameStateNotifier.state.rushSecondsRemaining, 10);

        await _advance(game, 3);

        expect(game.gameStateNotifier.state.rushSecondsRemaining, 7);
      },
    );
  });
}
