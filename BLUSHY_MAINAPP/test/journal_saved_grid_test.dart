import 'package:blushy_life_app/features/journal/notes/note_page_background.dart';
import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:blushy_life_app/features/journal/notes/notes_journal_screen.dart';
import 'package:blushy_life_app/features/journal/repository/journal_repository.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Saved journals stand upright.
///
/// They were full-width blocks as tall as their text, which read as list rows
/// rather than as pages -- a page is taller than it is wide, and that is the
/// shape it was chosen in. Each saved entry is now a page, two to a row, drawn
/// in the paper it was written on.

Widget _host(Widget child) => MaterialApp(home: child);

/// A session, because BlushyStorage refuses private writes without one --
/// the journal is private health data, so an unauthenticated write is dropped
/// on the floor and the screen loads nothing.
void _signIn() {
  AuthStorage.saveSession(
    token: 'test-token',
    userId: 'test-user',
    email: 'a@b.c',
    role: 'woman',
    onboardingCompleted: true,
  );
}

Future<void> _seed(List<LocalJournalEntry> entries) async {
  final repository = JournalRepository();
  for (final entry in entries) {
    await repository.addOrUpdateEntry(AuthStorage.getUserId() ?? 'anon', entry);
  }
}

LocalJournalEntry _entry({
  required String id,
  required String title,
  required NoteTemplate template,
  String body = 'a few words about the day',
  String date = '2026-09-14',
}) =>
    LocalJournalEntry(
      id: id,
      date: date,
      title: title,
      body: body,
      moodKey: 'calm',
      dateTime: '${date}T09:00:00.000',
      rawJson: NoteStyle(template: template).encode(),
    );

void main() {
  useIsolatedStorage();

  testWidgets('each saved journal is taller than it is wide', (tester) async {
    _signIn();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _seed([
      _entry(id: 'a', title: 'Monday', template: NoteTemplate.gingham),
      _entry(id: 'b', title: 'Tuesday', template: NoteTemplate.lined),
    ]);

    await tester.pumpWidget(_host(const NotesJournalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);

    for (final title in ['Monday', 'Tuesday']) {
      // The card's own clip: the innermost one above the title, whose size is
      // the tile the entry is drawn in.
      final card = tester.getSize(find
          .ancestor(of: find.text(title), matching: find.byType(ClipRRect))
          .first);
      expect(card.height, greaterThan(card.width),
          reason: '$title should be a page, not a row');
    }
  });

  testWidgets('two stand side by side, so the shelf is scannable',
      (tester) async {
    // Upright and full-width would put one entry on a screen.
    _signIn();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _seed([
      _entry(
        id: 'b',
        title: 'Older',
        template: NoteTemplate.dotted,
        date: '2026-09-12',
      ),
      _entry(
        id: 'a',
        title: 'Newer',
        template: NoteTemplate.plain,
        date: '2026-09-14',
      ),
    ]);

    await tester.pumpWidget(_host(const NotesJournalScreen()));
    await tester.pumpAndSettle();

    final newer = tester.getTopLeft(find.text('Newer'));
    final older = tester.getTopLeft(find.text('Older'));
    expect(older.dy, closeTo(newer.dy, 1),
        reason: 'the first two entries share a row');
    expect(older.dx, greaterThan(newer.dx),
        reason: 'newest first, so the newer one leads the row');
  });

  testWidgets('an entry is still drawn in the paper it was written on',
      (tester) async {
    _signIn();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _seed([
      _entry(id: 'a', title: 'On botanical', template: NoteTemplate.botanical),
    ]);

    await tester.pumpWidget(_host(const NotesJournalScreen()));
    await tester.pumpAndSettle();

    final drawn = tester
        .widgetList<NotePageBackground>(find.byType(NotePageBackground))
        .map((w) => w.style.template)
        .toList();
    expect(drawn, contains(NoteTemplate.botanical));
  });

  testWidgets('the way in is a Create Journal button at the bottom',
      (tester) async {
    _signIn();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const NotesJournalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Create Journal'), findsOneWidget);

    // In the Scaffold's bottom slot rather than floating over the entries, so
    // it never covers the last one.
    expect(find.byType(FloatingActionButton), findsNothing);
    final button = tester.getCenter(find.text('Create Journal'));
    expect(button.dy, greaterThan(700), reason: 'at the bottom of a 900 view');
  });

  testWidgets('with nothing written the empty state points at the button',
      (tester) async {
    _signIn();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const NotesJournalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Nothing written yet.'), findsOneWidget);
    expect(
      find.textContaining('Tap Create Journal'),
      findsOneWidget,
      reason: 'the copy should name the button that is actually there',
    );
  });
}
