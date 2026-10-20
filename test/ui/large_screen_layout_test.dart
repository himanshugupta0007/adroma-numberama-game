import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:numberama/game/numberama_game.dart';
import 'package:numberama/main.dart';
import 'package:numberama/state/preferences_service.dart';
import 'package:numberama/ui/gameplay/power_bar.dart';
import 'package:numberama/widgets/dialog_card.dart';
import 'package:numberama/widgets/gradient_button.dart';
import 'package:numberama/widgets/max_width_box.dart';

import '../helpers/test_prefs_box.dart';

/// Logical screen sizes (portrait) for the devices in the release test list.
const _smallPhone = Size(360, 640); // small/older phone
const _phone = Size(412, 915); // Pixel 8-class phone
const _foldUnfolded = Size(673, 841); // Pixel Fold, inner screen
const _tablet = Size(800, 1280); // Pixel Tablet, portrait

/// Status bar + display cutout on top, gesture/3-button bar at the bottom.
const _topInset = 48.0;
const _bottomInset = 48.0;

/// FlameGame ticks every frame, so `pumpAndSettle` never settles once a
/// GameWidget is live - pump a bounded number of frames instead.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Sizes the test window like a real device (1 logical px = 1 physical px)
/// with system bars reserving [_topInset]/[_bottomInset].
void _useScreen(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = const FakeViewPadding(top: _topInset, bottom: _bottomInset)
    ..viewPadding =
        const FakeViewPadding(top: _topInset, bottom: _bottomInset);
  addTearDown(tester.view.reset);
}

Future<void> _bootApp(WidgetTester tester) async {
  final box = await openTestPrefsBox(initial: {
    'has_seen_how_to_play': true,
    'has_seen_onboarding': true,
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferencesBoxProvider.overrideWithValue(box)],
      child: const NumberamaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openClassicRound(WidgetTester tester) async {
  final playClassic = find.widgetWithText(GradientButton, 'Play Classic');
  await tester.ensureVisible(playClassic);
  await tester.pump();
  await tester.tap(playClassic);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Medium'));
  await _pumpFrames(tester, frames: 60);
}

/// The content column must be at most [MaxWidthBox.screen] wide and
/// horizontally centred on the screen.
void _expectCentredAndCapped(Rect rect, Size screen) {
  expect(rect.width, lessThanOrEqualTo(MaxWidthBox.screen));
  final leftGap = rect.left;
  final rightGap = screen.width - rect.right;
  expect((leftGap - rightGap).abs(), lessThan(1),
      reason: 'content should be centred, got gaps $leftGap / $rightGap');
}

/// Top of the content sits below the status bar/cutout, bottom above the
/// navigation bar.
void _expectInsideSafeArea(Rect rect, Size screen) {
  expect(rect.top, greaterThanOrEqualTo(_topInset));
  expect(rect.bottom, lessThanOrEqualTo(screen.height - _bottomInset));
}

void main() {
  for (final (name, size) in [
    ('small phone', _smallPhone),
    ('phone', _phone),
    ('unfolded foldable', _foldUnfolded),
    ('tablet', _tablet),
  ]) {
    group('on a $name (${size.width.toInt()}x${size.height.toInt()})', () {
      testWidgets('home content is capped, centred and inside the safe area',
          (tester) async {
        _useScreen(tester, size);
        await _bootApp(tester);

        final playClassic =
            find.widgetWithText(GradientButton, 'Play Classic');
        final rect = tester.getRect(playClassic);
        _expectCentredAndCapped(rect, size);
        expect(rect.top, greaterThanOrEqualTo(_topInset));
        // On a phone the cap never kicks in - the layout keeps the full
        // screen width.
        if (size.width <= MaxWidthBox.screen) {
          expect(tester.getSize(find.byType(MaxWidthBox)).width, size.width);
        }
      });

      testWidgets(
          'the game board and power bar stay inside the capped, safe area',
          (tester) async {
        _useScreen(tester, size);
        await _bootApp(tester);
        await _openClassicRound(tester);

        final board = tester.getRect(find.byType(GameWidget<NumberamaGame>));
        _expectCentredAndCapped(board, size);
        _expectInsideSafeArea(board, size);

        final powerBar = tester.getRect(find.byType(PowerBar));
        _expectCentredAndCapped(powerBar, size);
        _expectInsideSafeArea(powerBar, size);

        // The top bar (back/help/pause icons) clears the status bar.
        final back = tester.getRect(find.byIcon(Icons.chevron_left_rounded));
        expect(back.top, greaterThanOrEqualTo(_topInset));
      });

      testWidgets('dialogs stay card-sized and fully on screen',
          (tester) async {
        _useScreen(tester, size);
        await _bootApp(tester);
        await _openClassicRound(tester);

        await tester.tap(find.byIcon(Icons.help_outline_rounded));
        await _pumpFrames(tester, frames: 40);

        // The Dialog widget itself spans the whole inset area; its Material
        // is the visible card.
        final dialog = tester.getRect(find
            .descendant(
                of: find.byType(DialogCard), matching: find.byType(Material))
            .first);
        expect(dialog.width, lessThanOrEqualTo(MaxWidthBox.dialog));
        _expectInsideSafeArea(dialog, size);
        // No RenderFlex overflow was reported while laying it out.
        expect(tester.takeException(), isNull);
      });
    });
  }
}
