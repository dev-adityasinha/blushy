import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:blushy_life_app/features/journal/notes/notes_journal_screen.dart';
import 'package:blushy_life_app/features/journal/repository/journal_repository.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The journal home, as a place rather than a list.
///
/// It was an app bar reading "Journal" and a grid of entries. It now opens
/// with what this place is, one question for today, and the two ways in that
/// actually exist -- and the entries can be read as pages or as a timeline.
///
/// Two things these guard. Voice capture is deliberately absent rather than
/// shown and inert: a way in that does nothing is worse than one not offered
/// yet. And the prompt is chosen by the day, not at random -- one that changed
/// on every rebuild would be impossible to sit with.

Widget _host(Widget child) => MaterialApp(home: child);

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
  required String date,
  NoteTemplate template = NoteTemplate.plain,
}) =>
    LocalJournalEntry(
      id: id,
      date: date,
      title: title,
      body: title,
      moodKey: '',
      dateTime: '${date}T09:00:00.000',
      rawJson: NoteStyle(template: template).encode(),
    );

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(const NotesJournalScreen()));
  await tester.pumpAndSettle();
}

void main() {
  useIsolatedStorage();

  testWidgets('it opens by saying what this place is', (tester) async {
    _signIn();
    await _open(tester);

    expect(find.text('JOURNAL'), findsOneWidget);
    expect(find.text('Your life, in your words.'), findsOneWidget);
    expect(
      find.textContaining("everything you don't want to lose"),
      findsOneWidget,
    );
  });

  testWidgets('today asks a question, and offers the ways in that exist',
      (tester) async {
    _signIn();
    await _open(tester);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('What happened today?'), findsOneWidget);
    expect(find.text('Tell me'), findsOneWidget);
    expect(find.text('Write it'), findsOneWidget);
    expect(find.text('Give me a prompt'), findsOneWidget);
  });

  testWidgets('once something is written today, the question changes',
      (tester) async {
    _signIn();
    final today = DateTime.now();
    final date = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    await _seed([_entry(id: 'a', title: 'already said it', date: date)]);

    await _open(tester);

    expect(find.text('Anything left unsaid?'), findsOneWidget);
    expect(find.text('What happened today?'), findsNothing);
  });

  /// Whatever question is currently on screen.
  String? _questionOnScreen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .firstWhere(
        (d) => d != null && d.endsWith('?') && d.length > 25,
        orElse: () => null,
      );

  testWidgets('not this one offers another, without leaving the dialog',
      (tester) async {
    // It used to just close: "not this one" gave you nothing instead of
    // something else, which is not what the words say.
    _signIn();
    await _open(tester);

    await tester.tap(find.text('Give me a prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Something to start from'), findsOneWidget);
    expect(find.text('Write about it'), findsOneWidget);

    final first = _questionOnScreen(tester);
    expect(first, isNotNull);

    await tester.tap(find.text('Not this one'));
    await tester.pumpAndSettle();

    // Still open, with a different question.
    expect(find.text('Something to start from'), findsOneWidget);
    final second = _questionOnScreen(tester);
    expect(second, isNotNull);
    expect(second, isNot(first), reason: 'another one, not the same one');
  });

  testWidgets('the day picks the first question, so it is the same all day',
      (tester) async {
    // A question that differed on every rebuild could not be sat with.
    _signIn();
    await _open(tester);

    await tester.tap(find.text('Give me a prompt'));
    await tester.pumpAndSettle();
    final first = _questionOnScreen(tester);

    // Dismiss without asking for another, then open it again.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give me a prompt'));
    await tester.pumpAndSettle();

    expect(_questionOnScreen(tester), first);
  });

  testWidgets('entries can be read as pages or as a timeline', (tester) async {
    _signIn();
    await _seed([
      _entry(id: 'a', title: 'Sunday walk', date: '2026-09-14'),
      _entry(id: 'b', title: 'A quieter one', date: '2026-08-30'),
    ]);
    await _open(tester);

    expect(find.text('YOUR MEMORIES'), findsOneWidget);

    // Pages by default: the shelf of upright papers.
    expect(find.byType(GridView), findsNothing,
        reason: 'the grid is a sliver inside the scroll view now');
    expect(find.text('September'), findsNothing);

    await tester.tap(find.byIcon(Icons.notes_rounded));
    await tester.pumpAndSettle();

    // The timeline groups by month and leads with the day.
    expect(find.text('September'), findsOneWidget);
    expect(find.text('August'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Sunday walk'), findsOneWidget);
  });

  testWidgets('the timeline says which paper an entry was written on',
      (tester) async {
    // The one thing the app actually knows about an entry beyond its words.
    // A mood tag would have to be guessed, and guessing it is the thing the
    // journal must not do.
    _signIn();
    await _seed([
      _entry(
        id: 'a',
        title: 'On gingham',
        date: '2026-09-14',
        template: NoteTemplate.gingham,
      ),
    ]);
    await _open(tester);

    await tester.tap(find.byIcon(Icons.notes_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Gingham'), findsOneWidget);
  });

  testWidgets('with nothing written, the memories section is absent',
      (tester) async {
    _signIn();
    await _open(tester);

    expect(find.text('YOUR MEMORIES'), findsNothing,
        reason: 'no heading over an empty shelf');
    expect(find.text('Nothing written yet.'), findsOneWidget);
    // But the way in is still there, above and below.
    expect(find.text('Write it'), findsOneWidget);
    expect(find.text('Create Journal'), findsOneWidget);
  });
}
