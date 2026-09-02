import 'package:blushy_life_app/shared/section_heading.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dashboard headings, and the answer to "why are you asking me this?"
///
/// The home tab asks for moods, symptoms, sleep and cycle dates, and no
/// heading said what any of it was for. Several also use words -- luteal,
/// follicular, rhythm -- that mean nothing unless you already know them.
Widget _host(String title) => MaterialApp(
      home: Scaffold(body: Center(child: SectionHeading(title))),
    );

void main() {
  testWidgets('a heading is red, with an info button', (tester) async {
    await tester.pumpWidget(_host('TODAY\'S CHECK-IN'));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('TODAY\'S CHECK-IN'));
    expect(text.style?.color, BlushyColors.primary);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });

  testWidgets('tapping it says why that section exists', (tester) async {
    await tester.pumpWidget(_host('TODAY\'S CHECK-IN'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Why this is here'), findsOneWidget);
    expect(find.textContaining('what the rest of the app is built on'),
        findsOneWidget);
  });

  testWidgets('cycle sections also explain the words they use', (tester) async {
    await tester.pumpWidget(_host('MY CYCLE HEALTH'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('What the words mean'), findsOneWidget);
    expect(find.text('Follicular phase'), findsOneWidget);
    expect(find.text('Luteal phase'), findsOneWidget);
    expect(find.text('Cycle rhythm'), findsOneWidget);
  });

  testWidgets('a section with no cycle words does not show the glossary',
      (tester) async {
    await tester.pumpWidget(_host('LEARN'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Why this is here'), findsOneWidget);
    expect(find.text('What the words mean'), findsNothing);
  });

  test('every heading on the dashboard resolves to a reason', () {
    // Grouped by what the section asks for, so a stage-specific title still
    // lands on an answer rather than falling through to nothing.
    for (final title in const [
      'CONTINUE LEARNING', 'CURIOUS TODAY', 'CONNECT', 'GROWING JOURNEY',
      'MY FIRST CYCLES', 'UNDERSTAND MY CYCLE', "TODAY'S CYCLE", 'CHECK IN',
      'MY CYCLE HEALTH', "TODAY'S CHECK-IN", 'FOR YOUR NEXT APPOINTMENT',
      'UNDERSTANDING MY PATTERNS', 'LEARN', 'FERTILITY TIMELINE',
      'PARTNER MODE', 'BABY THIS WEEK', 'BABY PREPARATION', 'PARTNER & FAMILY',
      "TODAY'S WELLBEING", 'BABY & YOU', 'MY CHANGING CYCLE', 'MY WELLBEING',
      'LONG-TERM WELLNESS', 'MY WELLNESS', 'MY HABITS', "TODAY'S CONTEXT",
    ]) {
      expect(SectionHeading(title).runtimeType, SectionHeading, reason: title);
    }
  });
}
