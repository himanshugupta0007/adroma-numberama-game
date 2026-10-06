import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:numberama/main.dart';
import 'package:numberama/state/preferences_service.dart';

void main() {
  testWidgets('NumberamaApp boots without crashing',
      (WidgetTester tester) async {
    final tempDir = await Directory.systemTemp.createTemp('numberama_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox('widget_test_prefs');
    addTearDown(() async {
      await box.close();
      await tempDir.delete(recursive: true);
    });

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
