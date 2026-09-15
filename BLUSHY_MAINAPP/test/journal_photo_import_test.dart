import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The journal can take a photo from the gallery.
///
/// The "Photo Frames" tray offered "Add Polaroid Frame", and tapping it
/// inserted a *text* item reading "[Polaroid Memory]" — a placeholder standing
/// in for a picture. Meanwhile the `ScrapbookItem` model had carried a 'photo'
/// type from the start and the journal counted photos for its statistics, so
/// the feature was declared, measured, and never implemented.
///
/// Asserted against the source: exercising the real path needs a file picker,
/// a platform channel and an image codec, none of which exist in a widget test.
void main() {
  final source =
      File('lib/features/journal/journal_screen.dart').readAsStringSync();

  test('the photo tray picks a real image instead of inserting a placeholder', () {
    // The string survives in the comment explaining why it went, so this looks
    // for the placeholder being *inserted* rather than merely mentioned.
    expect(RegExp(r"_addItem\([^)]*'text'[^)]*Polaroid Memory").hasMatch(source), isFalse,
        reason: 'the placeholder should no longer be inserted as a text item');
    expect(source.contains('onTap: _addPhotoFromGallery'), isTrue,
        reason: 'the tray button should open the picker');
  });

  test('a photo becomes a photo item, not a text item', () {
    // Inserting it as text is what made the journal count zero photos while
    // appearing to hold them.
    final method = source.substring(source.indexOf('_addPhotoFromGallery() async'));
    final body = method.substring(0, method.indexOf('\n  }'));

    expect(RegExp(r"_addItem\([\s\S]*?'photo',").hasMatch(body), isTrue,
        reason: "the item type must be 'photo' so the statistics and the "
            'renderer both recognise it');
  });

  test('photos are downscaled before being embedded', () {
    // They travel inside the entry as a data URI, the same as voice notes. A
    // phone photo is several megabytes and base64 adds a third again, so
    // embedding the original would bloat every entry and its sync.
    expect(source.contains('_journalPhotoMaxWidth'), isTrue);
    expect(RegExp(r'targetWidth:\s*_journalPhotoMaxWidth').hasMatch(source), isTrue,
        reason: 'the codec should resize rather than embedding the original');
  });

  test('a smaller image is not upscaled into a larger file', () {
    // From the definition, not the first mention — the call site appears
    // earlier in the file.
    final method = source.substring(
        source.indexOf('_downscaleForJournal(Uint8List original)'));
    final body = method.substring(0, method.indexOf('\n  }'));

    expect(RegExp(r'width\s*<=\s*_journalPhotoMaxWidth').hasMatch(body), isTrue,
        reason: 'resizing a small image up makes the file bigger for no gain');
  });

  test('the renderer draws the photo', () {
    expect(source.contains("item.type == 'photo'"), isTrue,
        reason: 'without a render branch the item exists but shows nothing');
    expect(source.contains('Image.memory'), isTrue);
  });
}
