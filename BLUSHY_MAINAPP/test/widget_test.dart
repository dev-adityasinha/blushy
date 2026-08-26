import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Blushy OS Bootstrap Smoke Test', (WidgetTester tester) async {
    // Build the Blushy OS App and trigger a frame.
    await tester.pumpWidget(const BlushyApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify that the Blushy MaterialApp initializes cleanly
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}


