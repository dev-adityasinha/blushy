import 'package:blushy_life_app/features/journal/notes/note_paper.dart';
import 'package:blushy_life_app/features/journal/notes/note_photo.dart';
import 'package:blushy_life_app/features/journal/notes/note_style.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a note is stored and read back.
///
/// The style lives in the entry's `rawJson`, which held scrapbook items long
/// before it held one of these. So every read has to survive a value that is
/// not a style, and an entry written by an older build has none at all.
void main() {
  // GoogleFonts reaches for the asset manifest the first time a family is
  // used, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  // And it then tries to fetch the family over the network, which a test has
  // no business doing. Off, so the fallback path is what runs here -- the same
  // path a device with no connection takes.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('round trip', () {
    test('everything chosen comes back', () {
      const style = NoteStyle(
        template: NoteTemplate.grid,
        fontId: 'caveat',
        fontSize: 22,
        background: 0xFF2E2A28,
        stickers: [
          NoteSticker(emoji: '🌸', dx: 0.2, dy: 0.8, scale: 1.5),
          NoteSticker(emoji: '☕', dx: 0.6, dy: 0.1),
        ],
      );

      final back = NoteStyle.decode(style.encode());

      expect(back.template, NoteTemplate.grid);
      expect(back.fontId, 'caveat');
      expect(back.fontSize, 22);
      expect(back.background, 0xFF2E2A28);
      expect(back.stickers.length, 2);
      expect(back.stickers.first.emoji, '🌸');
      expect(back.stickers.first.dx, 0.2);
      expect(back.stickers.first.scale, 1.5);
    });
  });

  group('reading something that is not a style', () {
    test('an entry with no style opens on the default', () {
      // Every entry written before this existed.
      expect(NoteStyle.decode(null).template, NoteTemplate.plain);
      expect(NoteStyle.decode('').fontId, NoteStyle.fallback.fontId);
    });

    test('text that is not JSON does not throw', () {
      expect(NoteStyle.decode('not json').background,
          NoteStyle.fallback.background);
    });

    test('JSON that is not a style does not throw', () {
      // `rawJson` carried scrapbook items, which are a list.
      expect(NoteStyle.decode('[1,2,3]').fontId, NoteStyle.fallback.fontId);
      expect(NoteStyle.decode('{"items":[]}').template, NoteTemplate.plain);
    });

    test('an unknown font falls back rather than disappearing', () {
      final style = NoteStyle.decode('{"fontId":"comic-sans-9000"}');
      // Resolved to a real id at decode time, so the note is never left
      // pointing at a family that does not exist.
      expect(style.fontId, NoteStyle.fallback.fontId);
      expect(NoteFonts.has(style.fontId), isTrue);
    });

    test('an unknown template falls back to plain paper', () {
      expect(NoteStyle.decode('{"template":"papyrus"}').template,
          NoteTemplate.plain);
    });

    test('an absurd font size is clamped, not honoured', () {
      // A size of 900 renders one letter per screen and the note is lost.
      expect(NoteStyle.decode('{"fontSize":900}').fontSize, 30);
      expect(NoteStyle.decode('{"fontSize":1}').fontSize, 12);
      expect(NoteStyle.decode('{"fontSize":"big"}').fontSize,
          NoteStyle.fallback.fontSize);
    });
  });

  group('stickers', () {
    test('a position outside the page is pulled back onto it', () {
      // Otherwise the sticker cannot be seen, or dragged back.
      final style =
          NoteStyle.decode('{"stickers":[{"emoji":"x","dx":4,"dy":-2}]}');
      expect(style.stickers.single.dx, 1.0);
      expect(style.stickers.single.dy, 0.0);
    });

    test('a sticker with no emoji is dropped rather than rendered blank', () {
      final style = NoteStyle.decode('{"stickers":[{"dx":0.5,"dy":0.5}]}');
      expect(style.stickers, isEmpty);
    });

    test('a malformed sticker list does not take the note down', () {
      expect(NoteStyle.decode('{"stickers":"nope"}').stickers, isEmpty);
      expect(NoteStyle.decode('{"stickers":[1,2]}').stickers, isEmpty);
    });
  });

  group('legibility', () {
    test('dark paper gets light ink and light paper gets dark', () {
      // Without this the dark background renders near-black on near-black,
      // which is a note that cannot be read back.
      final onDark = NoteBackgrounds.inkFor(0xFF2E2A28);
      final onLight = NoteBackgrounds.inkFor(0xFFFFFBF5);

      expect(onDark.computeLuminance(), greaterThan(0.5));
      expect(onLight.computeLuminance(), lessThan(0.5));
    });

    test('every offered paper colour gets readable ink', () {
      for (final colour in NoteBackgrounds.all) {
        final paper = Color(colour);
        final ink = NoteBackgrounds.inkFor(colour);
        final contrast =
            (paper.computeLuminance() - ink.computeLuminance()).abs();
        expect(contrast, greaterThan(0.4),
            reason: 'ink on ${colour.toRadixString(16)} is too close to it');
      }
    });
  });

  group('decorated pages', () {
    final decorated =
        NoteTemplate.values.where((t) => t.isDecorated).toList();

    test('there are some, and the ruled ones are not among them', () {
      expect(decorated, isNotEmpty);
      for (final ruled in [
        NoteTemplate.plain,
        NoteTemplate.lined,
        NoteTemplate.dotted,
        NoteTemplate.grid,
      ]) {
        expect(ruled.isDecorated, isFalse);
        expect(ruled.inset, 0, reason: 'a ruled page is written to its edges');
      }
    });

    test('each carries the two colours it is drawn in', () {
      for (final t in decorated) {
        expect(t.ground, isNotNull, reason: '${t.id} has no ground');
        expect(t.accent, isNotNull, reason: '${t.id} has no accent');
      }
    });

    test('each leaves a margin for its decoration', () {
      // Zero inset would put the writing panel over the whole page and hide
      // whatever the template draws.
      for (final t in decorated) {
        expect(t.inset, greaterThan(0.0), reason: '${t.id} has no margin');
        expect(t.inset, lessThan(0.35), reason: '${t.id} leaves no room to write');
      }
    });

    test('a wider side margin still leaves a usable panel', () {
      // The botanical grows in a wide left margin; the panel must not vanish.
      for (final t in decorated) {
        final left = t.insetLeft ?? t.inset;
        expect(left, lessThan(0.40), reason: '${t.id} pushes the panel off');
      }
    });

    test('the panel is inside the page and the right way up', () {
      const size = Size(400, 600);
      for (final t in NoteTemplate.values) {
        final rect = NotePaper.panelRect(t, size);
        expect(rect.width, greaterThan(0), reason: '${t.id} has no width');
        expect(rect.height, greaterThan(0), reason: '${t.id} has no height');
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
    });

    test('a ruled page has no margin at all', () {
      const size = Size(400, 600);
      expect(NotePaper.panelRect(NoteTemplate.lined, size),
          const Rect.fromLTWH(0, 0, 400, 600));
    });

    test('every template has a label worth showing in the picker', () {
      final labels = <String>{};
      for (final t in NoteTemplate.values) {
        expect(t.label.trim(), isNotEmpty);
        expect(labels.add(t.label), isTrue, reason: '${t.label} is listed twice');
        expect(t.id.trim(), isNotEmpty);
      }
    });

    test('a decorated page survives the round trip', () {
      const style = NoteStyle(template: NoteTemplate.pressedFlowers);
      expect(NoteStyle.decode(style.encode()).template,
          NoteTemplate.pressedFlowers);
    });

    test('an entry saved before these existed still opens', () {
      // Its stored template id is one of the original four.
      expect(NoteStyle.decode('{"template":"lined"}').template,
          NoteTemplate.lined);
    });
  });

  group('the photo background', () {
    // A 1x1 PNG, base64. Enough to prove it decodes; the picker's shrinking is
    // exercised on a device, not here.
    const tinyPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    test('the photo template carries a fallback ground', () {
      // It has to render before a photo is chosen, and if a stored one will
      // not decode. Without a ground that is a blank page.
      expect(NoteTemplate.photo.isDecorated, isTrue);
      expect(NoteTemplate.photo.ground, isNotNull);
      expect(NoteTemplate.photo.inset, greaterThan(0.0));
    });

    test('a chosen photo survives the round trip', () {
      const style =
          NoteStyle(template: NoteTemplate.photo, photo: tinyPng);
      final back = NoteStyle.decode(style.encode());
      expect(back.template, NoteTemplate.photo);
      expect(back.photo, tinyPng);
      expect(NotePhoto.decode(back.photo), isNotNull);
    });

    test('an entry without one carries no key for it', () {
      // Rather than a null in every entry that has no photo.
      expect(const NoteStyle().toJson().containsKey('photo'), isFalse);
      expect(NoteStyle.decode('{}').photo, isNull);
    });

    test('a photo can be taken off again', () {
      // copyWith cannot express this: null there means "leave it alone", so
      // without withoutPhoto the photo could be changed but never removed.
      const style = NoteStyle(template: NoteTemplate.photo, photo: tinyPng);
      expect(style.copyWith().photo, tinyPng, reason: 'copyWith must not clear it');

      final cleared = style.withoutPhoto();
      expect(cleared.photo, isNull);
      // And everything else is kept.
      expect(cleared.template, NoteTemplate.photo);
      expect(cleared.fontId, style.fontId);
      expect(cleared.background, style.background);
    });

    test('a photo that will not decode costs the decoration, not the note', () {
      expect(NotePhoto.decode('not base64 at all'), isNull);
      expect(NotePhoto.decode(''), isNull);
      expect(NotePhoto.decode(null), isNull);
      // And the style itself still reads back.
      final style = NoteStyle.decode('{"template":"photo","photo":"@@@"}');
      expect(style.template, NoteTemplate.photo);
      expect(NotePhoto.decode(style.photo), isNull);
    });

    test('an empty photo string is treated as none', () {
      expect(NoteStyle.decode('{"photo":""}').photo, isNull);
      expect(NoteStyle.decode('{"photo":123}').photo, isNull);
    });

    test('the size cap is small enough to keep an entry loadable', () {
      // An entry is read and written whole, so one oversized background makes
      // every save of that note slow.
      expect(NotePhoto.maxEncodedBytes, lessThanOrEqualTo(1024 * 1024));
      expect(NotePhoto.maxWidth, lessThanOrEqualTo(1280),
          reason: 'a background sits behind a panel and is mostly covered');
    });
  });

  test('every font in the picker is resolvable by its id', () {
    // Not `textStyle()`: GoogleFonts fetches a family on first use and the
    // families are not bundled, so calling the builder in a unit test throws
    // asynchronously whatever the code does. What is checkable here is that
    // every id the picker offers round-trips through the lookup -- an id that
    // did not would silently render as Poppins with no way to tell.
    final ids = <String>{};
    for (final font in NoteFonts.all) {
      expect(NoteFonts.has(font.id), isTrue, reason: '${font.id} is unknown');
      expect(NoteFonts.byId(font.id).label, font.label);
      expect(ids.add(font.id), isTrue, reason: '${font.id} is listed twice');
      expect(font.label.trim(), isNotEmpty);
    }
    expect(NoteFonts.has(NoteStyle.fallback.fontId), isTrue,
        reason: 'the fallback must itself be a real font');
  });
}
