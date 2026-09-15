import 'dart:convert';

import 'package:blushy_life_app/features/journal/vault/year_in_review.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Year in Review, counted from what is stored.
///
/// It used to be eight pages of fixed text — "63 Memories captured", "78%
/// Satisfied & Peaceful", "Chennai Coast, Lakeside Park" — identical for
/// somebody with three hundred entries and somebody with none.
LocalJournalEntry _entry({
  required String id,
  required String iso,
  String title = '',
  String body = '',
  String moodKey = 'satisfied',
  int photos = 0,
}) {
  return LocalJournalEntry(
    id: id,
    date: iso.substring(0, 10),
    title: title,
    body: body,
    moodKey: moodKey,
    dateTime: iso,
    rawJson: jsonEncode({
      'items': [
        for (var i = 0; i < photos; i++) {'type': 'photo'},
      ],
    }),
  );
}

Widget _host(List<LocalJournalEntry> entries, {int year = 2026}) => MaterialApp(
      home: YearInReviewScrapbook(
        entries: entries,
        year: year,
        onClose: () {},
      ),
    );

void main() {
  testWidgets('an empty year says so instead of inventing one', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to look back on yet'), findsOneWidget);
    expect(find.textContaining('63 Memories'), findsNothing);
    expect(find.textContaining('Chennai Coast'), findsNothing);
  });

  testWidgets('the count is the number of entries in that year',
      (tester) async {
    await tester.pumpWidget(_host([
      _entry(id: '1', iso: '2026-01-04T09:00:00.000'),
      _entry(id: '2', iso: '2026-03-11T09:00:00.000'),
      // Belongs to a different year, so it is not counted.
      _entry(id: '3', iso: '2025-07-02T09:00:00.000'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('2 entries this year.'), findsOneWidget);
  });

  testWidgets('one entry reads as one, not "1 entries"', (tester) async {
    await tester.pumpWidget(_host([
      _entry(id: '1', iso: '2026-01-04T09:00:00.000'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('One entry this year.'), findsOneWidget);
  });

  testWidgets('moods are the ones actually logged', (tester) async {
    await tester.pumpWidget(_host([
      _entry(id: '1', iso: '2026-01-04T09:00:00.000', moodKey: 'happy'),
      _entry(id: '2', iso: '2026-01-05T09:00:00.000', moodKey: 'happy'),
      _entry(id: '3', iso: '2026-01-06T09:00:00.000', moodKey: 'sad'),
      _entry(id: '4', iso: '2026-01-07T09:00:00.000', moodKey: 'sad'),
    ]));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('50% very satisfied • 50% sad'), findsOneWidget);
  });

  testWidgets('a page with nothing behind it is left out', (tester) async {
    // No photos and no voice notes, so there is no "What you kept" page.
    await tester.pumpWidget(_host([
      _entry(id: '1', iso: '2026-01-04T09:00:00.000', body: 'a short note'),
    ]));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('What you kept'), findsNothing);
  });

  testWidgets('photos are counted from the entries that hold them',
      (tester) async {
    await tester.pumpWidget(_host([
      _entry(id: '1', iso: '2026-01-04T09:00:00.000', photos: 2),
      _entry(id: '2', iso: '2026-02-04T09:00:00.000', photos: 3),
    ]));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('5 photos'), findsOneWidget);
  });
}
