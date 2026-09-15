import 'package:blushy_life_app/shared/section_heading.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One heading style for every section.
///
/// The heading used to carry an info button that opened a "why this is
/// here" sheet. That went, by decision: the headings are red, larger, and
/// plain, with an optional mark before the words.
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  testWidgets('a heading is red, with no info button', (tester) async {
    await tester.pumpWidget(_host(const SectionHeading("TODAY'S CHECK-IN")));
    await tester.pump();

    final text = tester.widget<Text>(find.text("TODAY'S CHECK-IN"));
    expect(text.style?.color, BlushyColors.primary);
    expect(find.byIcon(Icons.info_outline_rounded), findsNothing,
        reason: 'the (i) was removed from every header');
    expect(find.byType(InkWell), findsNothing,
        reason: 'nothing on a heading is tappable');
  });

  testWidgets('every heading has a mark, chosen from its words',
      (tester) async {
    await tester.pumpWidget(_host(const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('CHECK IN'),
        SectionHeading('CYCLE PATTERNS & INSIGHTS'),
        SectionHeading('SOMETHING NEW ENTIRELY'),
      ],
    )));
    await tester.pump();

    expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
    // Unmatched words still get a mark, so no heading is the odd one out.
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.byType(Icon), findsNWidgets(3));
  });

  test('the same kind of section gets the same mark on every stage', () {
    expect(SectionHeading.iconFor("TODAY'S CHECK-IN"),
        SectionHeading.iconFor('CHECK IN'));
    expect(SectionHeading.iconFor('MY CYCLE HEALTH'),
        isNot(SectionHeading.iconFor('UNDERSTANDING MY PATTERNS')),
        reason: 'different kinds of section get different marks');
  });

  testWidgets('a mark passed in wins over the rule', (tester) async {
    await tester.pumpWidget(_host(const SectionHeading(
      "TODAY'S LOGGED SIGNALS",
      icon: Icons.monitor_heart_outlined,
    )));
    await tester.pump();

    expect(find.byIcon(Icons.monitor_heart_outlined), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.monitor_heart_outlined));
    expect(icon.color, BlushyColors.primary, reason: 'the mark is red too');
  });

  testWidgets('a long heading ellipsizes instead of overflowing',
      (tester) async {
    await tester.pumpWidget(_host(const SizedBox(
      width: 120,
      child: SectionHeading('A VERY LONG HEADING THAT CANNOT FIT HERE'),
    )));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
