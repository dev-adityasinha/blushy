import 'package:blushy_life_app/features/journal/notes/note_editor_screen.dart';
import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writing goes where it is put.
///
/// A note was one field anchored to the top of the page: everything began on
/// the first line and ran down, so anything that belonged in the middle had to
/// be pushed there with blank lines. Tapping the paper now starts a block at
/// that spot, and blocks can be dragged.
///
/// Two things this has to keep true. The entry's `body` is still one string,
/// because the list card previews it and search reads it -- so the blocks are
/// flattened in reading order rather than creation order. And a note saved
/// before any of this existed carries its words in `body` alone: opening one
/// has to show them, not a blank page.

Widget _host(Widget child) => MaterialApp(home: child);

Future<LocalJournalEntry?> _openEditor(
  WidgetTester tester, {
  LocalJournalEntry? entry,
}) async {
  LocalJournalEntry? saved;
  await tester.pumpWidget(_host(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              saved = await Navigator.of(context).push<LocalJournalEntry>(
                MaterialPageRoute(
                  builder: (_) => NoteEditorScreen(entry: entry),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return saved;
}

/// The paper, which is what a tap has to land on to start a block.
Finder _page() => find.byType(TextField).first;

void main() {
  testWidgets('a new note opens with one place to write', (tester) async {
    await _openEditor(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('Tap anywhere on the page and write.'),
      findsOneWidget,
      reason: 'the page has to say it can be written on anywhere',
    );
  });

  testWidgets('tapping the middle of the page starts writing there',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openEditor(tester);
    await tester.enterText(_page(), 'at the top');
    await tester.pump();

    // Somewhere well below the first block, on bare paper.
    await tester.tapAt(const Offset(120, 520));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2),
        reason: 'the tap should have started a second block');

    await tester.enterText(find.byType(TextField).last, 'and this in the middle');
    await tester.pump();

    expect(find.text('at the top'), findsOneWidget);
    expect(find.text('and this in the middle'), findsOneWidget);
  });

  testWidgets('a block started lower down sits lower down', (tester) async {
    // If position were ignored the second block would render on top of the
    // first, and the page would look like one field again.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openEditor(tester);
    await tester.enterText(_page(), 'first');
    await tester.pump();

    await tester.tapAt(const Offset(140, 560));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'second');
    await tester.pump();

    final top = tester.getTopLeft(find.byType(TextField).first);
    final lower = tester.getTopLeft(find.byType(TextField).last);
    expect(lower.dy, greaterThan(top.dy + 100),
        reason: 'the second block should be where it was tapped');
    expect(lower.dx, greaterThan(top.dx),
        reason: 'and across, not back at the margin');
  });

  testWidgets('an empty block left behind does not stay on the page',
      (tester) async {
    // Every stray tap would otherwise leave an invisible box to trip over.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openEditor(tester);
    await tester.enterText(_page(), 'the only writing');
    await tester.pump();

    await tester.tapAt(const Offset(120, 520));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    // Focus something else without typing into the new block.
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget,
        reason: 'the blank block should have been dropped');
    expect(find.text('the only writing'), findsOneWidget);
  });

  testWidgets('what was written is saved in reading order', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    LocalJournalEntry? saved;
    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<LocalJournalEntry>(
                  MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Written lower first, then higher: the body must come back in page
    // order, not the order the blocks were made.
    await tester.tapAt(const Offset(120, 560));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'written second');
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'written first');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.body, 'written first\n\nwritten second');
    expect(saved!.title, 'written first',
        reason: 'the entry is named by the top of the page');

    // And the places travel with it.
    final style = NoteStyle.decode(saved!.rawJson);
    expect(style.blocks, hasLength(2));
    expect(style.blocks.last.dy, greaterThan(style.blocks.first.dy));
  });

  testWidgets('a note saved before any of this still opens with its words',
      (tester) async {
    // The record every existing entry has: a body, and a style with no blocks.
    final legacy = LocalJournalEntry(
      id: 'old',
      date: '2026-09-01',
      title: 'Older entry',
      body: 'written back when there was one box',
      moodKey: '',
      rawJson: const NoteStyle(template: NoteTemplate.lined).encode(),
    );

    await _openEditor(tester, entry: legacy);

    expect(find.text('written back when there was one box'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  test('a block records where it was put, and reads back there', () {
    const style = NoteStyle(blocks: [
      NoteTextBlock(text: 'in the middle', dx: 0.4, dy: 0.55, width: 0.5),
    ]);

    final restored = NoteStyle.decode(style.encode());
    expect(restored.blocks, hasLength(1));
    expect(restored.blocks.first.text, 'in the middle');
    expect(restored.blocks.first.dx, closeTo(0.4, 0.001));
    expect(restored.blocks.first.dy, closeTo(0.55, 0.001));
    expect(restored.blocks.first.width, closeTo(0.5, 0.001));
  });

  test('a position from a corrupted record cannot put words off the page', () {
    final wild = NoteTextBlock.fromJson(
      {'text': 'x', 'dx': 9.0, 'dy': -4.0, 'width': 0.0},
    );
    expect(wild, isNotNull);
    expect(wild!.dx, lessThanOrEqualTo(1.0));
    expect(wild.dy, greaterThanOrEqualTo(0.0));
    expect(wild.width, greaterThan(0.0));
  });

  test('a note with no blocks writes none into its record', () {
    // So an entry saved by an older build round-trips byte-identically.
    expect(const NoteStyle().encode().contains('blocks'), isFalse);
  });
}
