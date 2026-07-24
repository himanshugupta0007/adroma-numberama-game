import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/game/selection_manager.dart';
import 'package:numberama/state/game_state.dart';
import 'package:numberama/ui/gameplay/power_bar.dart';

/// Throwaway verification: confirms the power bar actually replays its
/// "try me" zoom pulse after 3 consecutive misses, and does NOT after just
/// 1 or 2. Not part of the permanent suite.
void main() {
  testWidgets('power bar pulses shuffle/hint after 3 consecutive misses',
      (tester) async {
    final notifier = GameStateNotifier();
    final game = NumberamaGame(gameStateNotifier: notifier);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameStateProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(height: 400, width: 400, child: GameWidget(game: game)),
                PowerBar(selectionManager: game.selectionManager),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    Future<double> pumpAndTrackMaxScale() async {
      var maxScale = 1.0;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final transitions = tester.widgetList<ScaleTransition>(
          find.byType(ScaleTransition),
        );
        for (final t in transitions) {
          final v = t.scale.value;
          if (v > maxScale) maxScale = v;
        }
      }
      return maxScale;
    }

    notifier.registerInvalidAttempt();
    notifier.registerInvalidAttempt();
    final scaleAfterTwo = await pumpAndTrackMaxScale();
    expect(scaleAfterTwo, lessThan(1.05),
        reason: 'should not pulse before the 3rd consecutive miss');

    notifier.registerInvalidAttempt();
    final scaleAfterThree = await pumpAndTrackMaxScale();
    expect(scaleAfterThree, greaterThan(1.2),
        reason: 'should pulse noticeably on the 3rd consecutive miss');
  });
}
