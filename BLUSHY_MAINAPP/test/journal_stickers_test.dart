import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stickers, and the seam artwork will drop into.
///
/// The set is Material glyphs — flat single-colour shapes by design, which is
/// why they read as emoji. No styling makes one look painted; that needs an
/// illustrated set. What can be built ahead of the art is the way it arrives,
/// so adding it later is a data change rather than a rewrite.
void main() {
  final journal =
      File('lib/features/journal/journal_screen.dart').readAsStringSync();

  test('a sticker can be backed by artwork', () {
    expect(journal.contains("stickerMap['asset']"), isTrue,
        reason: 'the renderer needs to prefer an image where one exists');
    expect(journal.contains('Image.asset'), isTrue);
  });

  test('a missing image costs a sticker, not the page', () {
    final start = journal.indexOf("final asset = stickerMap['asset']");
    expect(start, greaterThan(-1));
    final block = journal.substring(start, start + 700);
    expect(block.contains('errorBuilder'), isTrue,
        reason: 'a missing file should fall back to the glyph, not throw');
  });

  test('the asset travels with a saved entry', () {
    // Stored per item so an entry keeps the sticker it was made with, even if
    // the set changes later.
    expect(RegExp(r"if \(stickerMap\['asset'\] != null\) 'asset'").hasMatch(journal), isTrue);
  });

  test('sticker names carry no emoji', () {
    // The complaint is that they read as emoji; emoji in the names works
    // against that, and eight of ten had one while two did not.
    final start = journal.indexOf('_stickersList = [');
    final end = journal.indexOf('];', start);
    final list = journal.substring(start, end);

    final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    expect(emoji.hasMatch(list), isFalse,
        reason: 'sticker names should be words');
  });

  test('renaming did not orphan entries saved under the old names', () {
    // Saved stickers are resolved by name on load, and the old names were
    // '🦋 Butterfly' and the like. Matching on the word rather than the whole
    // string is what keeps those entries rendering.
    final start = journal.indexOf('IconData resolveIcon(String name)');
    expect(start, greaterThan(-1));
    final body = journal.substring(start, start + 800);

    expect(body.contains("name.contains('Butterfly')"), isTrue,
        reason: 'substring matching is what makes the rename backwards compatible');
    expect(body.contains("name == '"), isFalse,
        reason: 'exact matching here would blank every sticker saved before the rename');
  });

  test('the journal keeps one icon family', () {
    // 84 icons were rounded and 13 were not; those 13 were accidents rather
    // than a second convention.
    final files = [
      ...Directory('lib/features/journal').listSync(recursive: true),
      ...Directory('lib/features/m_studio').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));

    final offenders = <String>{};
    for (final f in files) {
      for (final m in RegExp(r'Icons\.[a-z_0-9]+').allMatches(f.readAsStringSync())) {
        if (!m[0]!.endsWith('_rounded')) offenders.add(m[0]!);
      }
    }

    expect(offenders, isEmpty,
        reason: 'these break the rounded convention: ${offenders.join(", ")}');
  });
}
