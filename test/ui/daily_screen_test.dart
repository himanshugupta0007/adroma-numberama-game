import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/game/tile_component.dart';
import 'package:numberama/main.dart';
import 'package:numberama/state/difficulty.dart';
import 'package:numberama/state/game_state.dart';
import 'package:numberama/state/preferences_service.dart';
import 'package:numberama/ui/daily/daily_screen.dart';
import 'package:numberama/ui/results/results_screen.dart';
import 'package:numberama/widgets/gradient_button.dart';

List<TileComponent>? _findValidPair(List<TileComponent> tiles) {
  for (var i = 0; i < tiles.length; i++) {
    for (var j = i + 1; j < tiles.length; j++) {
      final a = tiles[i];
      final b = tiles[j];
      if (a.value == b.value || a.value + b.value == 10) return [a, b];
    }
  }
  return null;
}

// Same reasoning as gameplay_flow_test.dart: FlameGame keeps scheduling
// frames once its GameWidget is live, so pumpAndSettle never settles.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

int _testBoxCounter = 0;

/// Boots the app (with How to Play already dismissed, so it doesn't block
/// taps) and returns the container so tests can read/seed the Hive box
/// directly.
Future<ProviderContainer> _bootApp(
  WidgetTester tester, {
  bool hasPlayedDailyToday = false,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('numberama_test_');
  Hive.init(tempDir.path);
  final box = await Hive.openBox('prefs_${_testBoxCounter++}');
  addTearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });
  await box.put('has_seen_how_to_play', true);
  if (hasPlayedDailyToday) {
    final now = DateTime.now();
    await box.put(
      'last_daily_played_date',
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}',
    );
  }

  final container = ProviderContainer(
    overrides: [preferencesBoxProvider.overrideWithValue(box)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NumberamaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openDaily(WidgetTester tester) async {
  final dailyCard = find.widgetWithText(ElevatedButton, 'Play Daily');
  await tester.ensureVisible(dailyCard);
  await tester.pump();
  await tester.tap(dailyCard);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      "today's difficulty chip is real and the start button is enabled "
      'before playing', (tester) async {
    await _bootApp(tester);
    await _openDaily(tester);

    final today = Difficulty.forDate(DateTime.now());
    expect(find.text(today.label), findsOneWidget);
    expect(find.text(dailySeedLabel(DateTime.now())), findsOneWidget);
    expect(find.widgetWithText(GradientButton, "Start today's board"),
        findsOneWidget);
  });

  testWidgets(
      'the calendar strip and start button already reflect a completed '
      'daily round', (tester) async {
    await _bootApp(tester, hasPlayedDailyToday: true);
    await _openDaily(tester);

    expect(find.widgetWithText(GradientButton, "Start today's board"),
        findsNothing);
    expect(find.textContaining('come back tomorrow'), findsOneWidget);
  });

  testWidgets(
      'finishing today\'s daily round locks it for the rest of the day',
      (tester) async {
    await _bootApp(tester);
    await _openDaily(tester);

    await tester.tap(find.widgetWithText(GradientButton, "Start today's board"));
    await _pumpFrames(tester, frames: 60);

    final game = tester
        .widget<GameWidget<NumberamaGame>>(find.byType(GameWidget<NumberamaGame>))
        .game!;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameWidget<NumberamaGame>)),
    );

    final pair = _findValidPair(game.gridComponent.activeTiles);
    expect(pair, isNotNull);
    final [tileA, tileB] = pair!;
    game.selectionManager.onTileTapped(tileA);
    game.selectionManager.onTileTapped(tileB);
    await _pumpFrames(tester);

    container.read(gameStateProvider.notifier).setPhase(GamePhase.won);
    await _pumpFrames(tester, frames: 40);

    expect(find.byType(ResultsScreen), findsOneWidget);
    final results = tester.widget<ResultsScreen>(find.byType(ResultsScreen));
    expect(results.isDaily, isTrue);
    expect(find.widgetWithText(GradientButton, 'Done for today'), findsOneWidget);

    // "Done for today" pops back to DailyScreen, which should now be locked.
    await tester.tap(find.widgetWithText(GradientButton, 'Done for today'));
    await _pumpFrames(tester, frames: 40);

    expect(find.byType(DailyScreen), findsOneWidget);
    expect(find.widgetWithText(GradientButton, "Start today's board"),
        findsNothing);
    expect(find.textContaining('come back tomorrow'), findsOneWidget);
  });
}
