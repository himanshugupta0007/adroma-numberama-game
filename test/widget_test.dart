import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:numberama/main.dart';

void main() {
  testWidgets('NumberamaApp boots without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NumberamaApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
