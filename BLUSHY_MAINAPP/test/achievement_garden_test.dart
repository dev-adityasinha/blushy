import 'dart:convert';

import 'package:blushy_life_app/features/journal/insights/achievement_garden.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The garden, grown from real entries.
///
/// Its three counts used to default to 12, 6 and 8, and every call site took
/// the defaults — so an account with nothing written still saw twelve flowers.
LocalJournalEntry _entry({
  required String id,
  String title = '',
  String body = '',
  String? template,
}) {
  return LocalJournalEntry(
    id: id,
    date: '2026-01-01',
    title: title,
    body: body,
    moodKey: 'satisfied',
    dateTime: '2026-01-01T09:00:00.000',
    rawJson: jsonEncode({'templateName': template ?? 'Daily Reflection', 'items': []}),
  );
}

void main() {
  test('nothing written grows nothing', () {
    final garden = AchievementGardenWidget.fromEntries(const []);

    expect(garden.totalGratitudeEntries, 0);
    expect(garden.totalTravelEntries, 0);
    expect(garden.totalFamilyEntries, 0);
  });

  test('gratitude comes from the template the entry was written on', () {
    final garden = AchievementGardenWidget.fromEntries([
      _entry(id: '1', template: 'Gratitude'),
      // The stage lists carry variants, matched the loose way the templates
      // themselves are matched.
      _entry(id: '2', template: 'Gratitude Log'),
      _entry(id: '3', template: 'Daily Reflection'),
    ]);

    expect(garden.totalGratitudeEntries, 2);
  });

  test('travel and family come from what the entry says', () {
    final garden = AchievementGardenWidget.fromEntries([
      _entry(id: '1', body: 'the flight was delayed but the hotel was lovely'),
      _entry(id: '2', title: 'A trip north'),
      _entry(id: '3', body: 'called mom about the weekend'),
      _entry(id: '4', body: 'nothing much happened today'),
    ]);

    expect(garden.totalTravelEntries, 2);
    expect(garden.totalFamilyEntries, 1);
  });

  testWidgets('the legend shows the counted numbers', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AchievementGardenWidget.fromEntries([
        _entry(id: '1', template: 'Gratitude'),
        _entry(id: '2', body: 'a trip to the coast'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 Flowers'), findsOneWidget);
    expect(find.text('1 Wildflowers'), findsOneWidget);
    expect(find.text('0 Trees'), findsOneWidget);

    // The old fixed numbers.
    expect(find.text('12 Flowers'), findsNothing);
    expect(find.text('8 Trees'), findsNothing);
  });
}
