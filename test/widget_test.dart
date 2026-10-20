import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:numberama/main.dart';
import 'package:numberama/state/preferences_service.dart';

import 'helpers/test_prefs_box.dart';

void main() {
  testWidgets('NumberamaApp boots without crashing',
      (WidgetTester tester) async {
    final box = await openTestPrefsBox();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesBoxProvider.overrideWithValue(box)],
        child: const NumberamaApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
