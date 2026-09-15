import 'package:blushy_life_app/features/journal/notes/note_editor_screen.dart';
import 'package:blushy_life_app/features/journal/notes/note_page_background.dart';
import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:blushy_life_app/features/journal/notes/note_template_picker_screen.dart';
import 'package:blushy_life_app/services/journal_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Choosing the page before writing on it.
///
/// The eleven papers were always there, but behind a toolbar icon inside the
/// editor -- so every new entry began on the plain default, and the rest were
/// only found by going looking. Writing now starts at the gallery.
///
/// Two things these pin. The gallery draws the real painter rather than a
/// picture of it, so what is tapped is what opens. And an existing entry
/// ignores the initial template entirely: reopening a note must not silently
/// restyle what is already written on it.

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('every paper that exists is offered, and no others',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const NoteTemplatePickerScreen()));
    await tester.pumpAndSettle();

    expect(NoteTemplatePickerScreen.templates, NoteTemplate.values,
        reason: 'the whole set, nothing added and nothing dropped');

    // The grid builds lazily, so the papers are gathered by scrolling the way
    // somebody choosing one would. Asserting on a single tall frame instead
    // would pass only until the next template was added.
    final seen = <String>{};
    for (var pass = 0; pass < 20; pass++) {
      seen.addAll(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
      );
      if (seen.containsAll(NoteTemplate.values.map((t) => t.label))) break;
      await tester.drag(find.byType(GridView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }

    for (final template in NoteTemplate.values) {
      expect(seen, contains(template.label), reason: template.label);
    }
  });

  testWidgets('each tile is drawn by the painter the editor uses',
      (tester) async {
    // A tile that were a picture could drift from the page it promises.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const NoteTemplatePickerScreen()));
    await tester.pumpAndSettle();

    final drawn = tester
        .widgetList<NotePageBackground>(find.byType(NotePageBackground))
        .map((w) => w.style.template)
        .toSet();

    // A grid builds lazily, so only what is on screen is required to be there.
    expect(drawn, isNotEmpty);
    expect(drawn.every(NoteTemplate.values.contains), isTrue);
    expect(drawn.contains(NoteTemplate.plain), isTrue,
        reason: 'the first tile is the first template');
  });

  testWidgets('tapping a page returns it to the caller', (tester) async {
    // Tall enough that the decorated papers are built: the grid is lazy, and
    // Gingham is on the third row.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    NoteTemplate? chosen;

    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<NoteTemplate>(
                  MaterialPageRoute(
                    builder: (_) => const NoteTemplatePickerScreen(),
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

    await tester.scrollUntilVisible(find.text('Gingham'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gingham'));
    await tester.pumpAndSettle();

    expect(chosen, NoteTemplate.gingham);
  });

  testWidgets('backing out of the gallery chooses nothing', (tester) async {
    // Opening the editor on a page nobody picked would leave an empty entry
    // behind every time someone changed their mind.
    NoteTemplate? chosen = NoteTemplate.ribbon;

    await tester.pumpWidget(_host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<NoteTemplate>(
                  MaterialPageRoute(
                    builder: (_) => const NoteTemplatePickerScreen(),
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
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(chosen, isNull);
  });

  testWidgets('a new entry opens on the page that was chosen', (tester) async {
    await tester.pumpWidget(_host(
      const NoteEditorScreen(initialTemplate: NoteTemplate.botanical),
    ));
    await tester.pumpAndSettle();

    final page = tester.widget<NotePageBackground>(
      find.byType(NotePageBackground).first,
    );
    expect(page.style.template, NoteTemplate.botanical);
  });

  testWidgets('reopening an entry keeps its own page, not the chosen one',
      (tester) async {
    // The editor takes both when a saved entry is tapped from the list; the
    // entry has to win, or every reopen would restyle the note.
    const stored = NoteStyle(template: NoteTemplate.gingham);

    await tester.pumpWidget(_host(
      NoteEditorScreen(
        entry: LocalJournalEntry(
          id: 'e1',
          date: '2026-09-14',
          title: 'Written on gingham',
          body: 'and it should stay that way',
          moodKey: 'calm',
          rawJson: stored.encode(),
        ),
        initialTemplate: NoteTemplate.wavyFrame,
      ),
    ));
    await tester.pumpAndSettle();

    final page = tester.widget<NotePageBackground>(
      find.byType(NotePageBackground).first,
    );
    expect(page.style.template, NoteTemplate.gingham);
  });

  testWidgets('with no page chosen the editor still opens, on the default',
      (tester) async {
    await tester.pumpWidget(_host(const NoteEditorScreen()));
    await tester.pumpAndSettle();

    final page = tester.widget<NotePageBackground>(
      find.byType(NotePageBackground).first,
    );
    expect(page.style.template, NoteTemplate.plain);
  });
}
