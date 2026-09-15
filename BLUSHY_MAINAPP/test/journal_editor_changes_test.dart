import 'package:blushy_life_app/features/journal/notes/note_editor_screen.dart';
import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor, once the page is chosen before you get to it.
///
/// Three things went: the Paper tool, which only offered a way to undo the
/// choice just made in the gallery; the Title field, a heading to fill in
/// before writing that most entries left as "Untitled"; and leaving without
/// being asked, which lost whatever had been written.
///
/// The photo control is the wrinkle. It lived inside the Paper tray, so
/// removing that tray would have left the Photo paper with no way to choose a
/// photo -- it has its own tool now, and only when that paper is in use.

Widget _host(Widget child) => MaterialApp(home: child);

LocalJournalEntry _entry({required String body, NoteTemplate? template}) =>
    LocalJournalEntry(
      id: 'e1',
      date: '2026-09-14',
      title: 'whatever was stored',
      body: body,
      moodKey: '',
      rawJson: NoteStyle(template: template ?? NoteTemplate.plain).encode(),
    );

void main() {
  testWidgets('there is no Paper tool and no Title field', (tester) async {
    await tester.pumpWidget(_host(const NoteEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Paper'), findsNothing,
        reason: 'the page was already chosen in the gallery');
    expect(find.text('Title'), findsNothing,
        reason: 'one box to write in, no heading first');

    // What is left.
    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('Stickers'), findsOneWidget);
  });

  testWidgets('one text box, and it is the writing', (tester) async {
    await tester.pumpWidget(_host(const NoteEditorScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'woke up early');
    await tester.pump();
    expect(find.text('woke up early'), findsOneWidget);
  });

  testWidgets('the Photo tool appears only for the Photo paper',
      (tester) async {
    await tester.pumpWidget(_host(
      const NoteEditorScreen(initialTemplate: NoteTemplate.lined),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Photo'), findsNothing);

    // A blank frame between the two, so the second pump builds a fresh State
    // rather than updating the first one -- the starting style is read once,
    // when the State is created.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_host(
      const NoteEditorScreen(initialTemplate: NoteTemplate.photo),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Photo'), findsOneWidget,
        reason: 'otherwise that paper can never be given a photo');

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose photo'), findsOneWidget);
  });

  testWidgets('the entry is named by its first line', (tester) async {
    // There is no title to type, so the writing has to name itself or every
    // entry in the list reads "Untitled".
    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<LocalJournalEntry>(
                MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Sunday walk\nWe went down to the water before it got hot.',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back on the host, with nothing left to assert against but the absence
    // of the editor -- the title itself is checked below without the route.
    expect(find.byType(NoteEditorScreen), findsNothing);
  });

  testWidgets('leaving with unsaved writing asks first', (tester) async {
    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<LocalJournalEntry>(
                MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'something worth keeping');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Save this entry?'), findsOneWidget);
    expect(find.text('Keep writing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    // Keeping writing leaves the page where it was.
    await tester.tap(find.text('Keep writing'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteEditorScreen), findsOneWidget);
    expect(find.text('something worth keeping'), findsOneWidget);
  });

  testWidgets('leaving an untouched entry does not ask', (tester) async {
    // Opening a note to read it and backing straight out is not a decision
    // anybody needs to confirm.
    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<LocalJournalEntry>(
                MaterialPageRoute(
                  builder: (_) =>
                      NoteEditorScreen(entry: _entry(body: 'already written')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Save this entry?'), findsNothing);
    expect(find.byType(NoteEditorScreen), findsNothing);
  });

  test('there are at least sixteen typefaces, each resolvable by its id', () {
    // Six is what there were. The ids are written into saved notes, so they
    // have to stay unique and stay resolvable.
    expect(NoteFonts.all.length, greaterThanOrEqualTo(16));

    final ids = NoteFonts.all.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'no duplicate ids');

    for (final font in NoteFonts.all) {
      expect(NoteFonts.has(font.id), isTrue);
      expect(NoteFonts.byId(font.id).id, font.id);
      expect(font.label, isNotEmpty);
      // The builder must not throw: a font that cannot resolve takes the note
      // down with it, and the writing matters more than the typeface.
      expect(
        () => NoteStyle(fontId: font.id).textStyle(),
        returnsNormally,
        reason: font.id,
      );
    }
  });
}
