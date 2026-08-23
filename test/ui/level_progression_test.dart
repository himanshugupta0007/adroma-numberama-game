import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/game/tile_component.dart';
import 'package:numberama/main.dart';
import 'package:numberama/state/game_state.dart';
import 'package:numberama/state/preferences_service.dart';

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

Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

int _testBoxCounter = 0;

void main() {
  testWidgets(
      'clearing a real Classic pair through the live app awards XP, and the '
      'level pill/home badge both reflect it', (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('numberama_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('level_progression_${_testBoxCounter++}');
    addTearDown(() async {
      await box.close();
      await tempDir.delete(recursive: true);
    });
    await box.put('has_seen_how_to_play', true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesBoxProvider.overrideWithValue(box)],
        child: const NumberamaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // No level badge yet - a brand-new player has never cleared a pair.
    expect(find.textContaining('LEVEL'), findsNothing);

    await tester.tap(find.text('Play Classic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium'));
    await _pumpFrames(tester, frames: 60);

    final game = tester
        .widget<GameWidget<NumberamaGame>>(find.byType(GameWidget<NumberamaGame>))
        .game!;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameWidget<NumberamaGame>)),
    );

    // The bug this guards against: XP is only ever awarded when
    // GameState.difficulty is non-null (Classic) - if a future change
    // regresses the startGame(difficulty:) wiring, this catches it before
    // the XP assertion below would otherwise fail more confusingly.
    expect(container.read(gameStateProvider).difficulty, isNotNull);

    final pair = _findValidPair(game.gridComponent.activeTiles);
    expect(pair, isNotNull,
        reason: 'expected at least one valid pair in a fresh grid');
    final [tileA, tileB] = pair!;
    game.selectionManager.onTileTapped(tileA);
    game.selectionManager.onTileTapped(tileB);
    await _pumpFrames(tester);

    // baseXp 10 * Medium's 1.5x multiplier = 15.
    expect(box.get('total_xp'), 15);
    // Still level 1 (200 XP needed for level 2) - the in-round pill should
    // already be showing it, next to the score.
    expect(find.textContaining('Lv. 1'), findsOneWidget);

    // Back to Home (via the confirm-exit dialog) - the home screen should
    // now show the level badge, reading from the very same box.
    //
    // Bounded pumps only, not pumpAndSettle: GameWidget's Flame ticker is
    // still mounted underneath the confirm dialog (and briefly during the
    // pop transition), scheduling a new frame every frame - see
    // gameplay_flow_test.dart's _pumpFrames doc for the same constraint.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await _pumpFrames(tester, frames: 20);
    await tester.tap(find.text('Leave'));
    await _pumpFrames(tester, frames: 40);

    expect(find.textContaining('LEVEL 1'), findsOneWidget);
  });
}
