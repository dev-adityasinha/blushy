import 'package:blushy_life_app/features/journal/notes/note_stickers.dart';
import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stickers the app draws, rather than whatever the device's emoji font has.
///
/// The palette was emoji only: a different shape on every phone, and nothing
/// that belonged to this app. These are drawn, so a note looks the same
/// everywhere and stays sharp at any size.
///
/// The thing most worth pinning is the older records. Every note already saved
/// carries `emoji` and no id, and those have to keep opening exactly as they
/// did -- which is why the id sits beside the emoji rather than replacing it.

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('every sticker has a stable id, and ids are unique', () {
    // The id is what gets written into a saved note. Two stickers sharing one,
    // or one changing, silently rewrites what somebody stuck on their page.
    final ids = JournalSticker.values.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'no duplicate ids');
    for (final sticker in JournalSticker.values) {
      expect(sticker.id, isNotEmpty);
      expect(sticker.label, isNotEmpty, reason: '${sticker.id} needs a name');
      expect(JournalSticker.byId(sticker.id), sticker);
    }
  });

  test('an unknown id resolves to nothing rather than throwing', () {
    // A note written by a newer build, or a hand-edited record.
    expect(JournalSticker.byId('not-a-sticker'), isNull);
    expect(JournalSticker.byId(null), isNull);
    expect(JournalSticker.byId(''), isNull);
  });

  test('a drawn sticker survives being saved and read back', () {
    const original = NoteStyle();
    final withSticker = original.copyWith(stickers: [
      NoteSticker.drawn(JournalSticker.cherry, dx: 0.25, dy: 0.6, scale: 1.5),
    ]);

    final restored = NoteStyle.decode(withSticker.encode());
    expect(restored.stickers, hasLength(1));
    expect(restored.stickers.first.drawn, JournalSticker.cherry);
    expect(restored.stickers.first.dx, closeTo(0.25, 0.001));
    expect(restored.stickers.first.scale, closeTo(1.5, 0.001));
  });

  test('an emoji sticker saved by an older build still opens', () {
    // The exact record shape older builds wrote: an emoji, no id.
    const stored = '{"template":"plain","fontId":"poppins","fontSize":16,'
        '"background":4294965237,'
        '"stickers":[{"emoji":"\u{1F338}","dx":0.5,"dy":0.3,"scale":1.0}]}';

    final style = NoteStyle.decode(stored);
    expect(style.stickers, hasLength(1));
    expect(style.stickers.first.emoji, '\u{1F338}');
    expect(style.stickers.first.drawn, isNull,
        reason: 'nothing drawn, so it renders as the emoji it always was');
  });

  test('a record with neither an emoji nor an id is dropped', () {
    expect(
      NoteSticker.fromJson({'dx': 0.5, 'dy': 0.5}),
      isNull,
      reason: 'there would be nothing to draw',
    );
  });

  test('moving a drawn sticker keeps it drawn', () {
    // copyWith rebuilds the record; dropping the id there would turn a cherry
    // into a blank the moment it was dragged.
    final moved = NoteSticker.drawn(JournalSticker.bow, dx: 0.2, dy: 0.2)
        .copyWith(dx: 0.8);
    expect(moved.drawn, JournalSticker.bow);
    expect(moved.dx, closeTo(0.8, 0.001));
  });

  testWidgets('every sticker paints something', (tester) async {
    // A painter that drew nothing would look like a missing sticker rather
    // than an error, and only on the one shape that was wrong.
    for (final sticker in JournalSticker.values) {
      await tester.pumpWidget(_host(
        Center(child: StickerIcon(sticker: sticker, size: 60)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: sticker.id);
      expect(find.byType(CustomPaint), findsWidgets, reason: sticker.id);
    }
  });

  testWidgets('a sticker draws at whatever size it is given', (tester) async {
    // The tray shows them at 28 and a page at 44 upward, from one set of
    // coordinates. A painter that assumed one size would be wrong in the other.
    for (final size in [16.0, 28.0, 96.0]) {
      await tester.pumpWidget(_host(
        Center(child: StickerIcon(sticker: JournalSticker.discoBall, size: size)),
      ));
      await tester.pump();

      final box = tester.getSize(find.byType(CustomPaint).last);
      expect(box.width, closeTo(size, 0.01), reason: 'at $size');
      expect(tester.takeException(), isNull);
    }
  });
}
