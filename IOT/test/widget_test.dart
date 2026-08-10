// Basic widget tests for the shared UI building blocks in `core/widgets.dart`.
//
// Note: the top-level `SmartMedicineCabinetApp` (lib/main.dart) initializes
// Firebase and can't be pumped directly in a plain widget test without
// mocking the Firebase platform channels, so these tests exercise
// standalone widgets instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iot_app/core/widgets.dart';

void main() {
  testWidgets('AppButton shows its label and responds to taps',
      (WidgetTester tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Continue',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('StatusBadge renders its label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(label: 'LOCKED', color: Colors.red),
        ),
      ),
    );

    expect(find.text('LOCKED'), findsOneWidget);
  });
}
