import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// M Studio against STAGE1_DESIGN_RULES.md.
///
/// The hub was four identical cards on a plain canvas: each one tinted with
/// its own accent, with an accent chip, an accent chevron and an accent
/// surface. Four cards in four colours means none of them is emphasised, and
/// the rules say so plainly -- accents belong on circular icon badges and
/// small pills, never as card surfaces or rainbow borders.
///
/// These read the source rather than render it. What is being pinned is that
/// the page uses the system's tokens, which is a claim about the code; the
/// look itself is a matter for the eye.

late final String _source;
late final String _rules;

void main() {
  setUpAll(() {
    _source = File('lib/features/m_studio/m_studio_screen.dart').readAsStringSync();
    _rules = File(
      'lib/features/home/presentation/stages/STAGE1_DESIGN_RULES.md',
    ).readAsStringSync();
  });

  test('the rules this page follows are still in the repository', () {
    // If the document moves, these tests are measuring nothing.
    expect(_rules, contains('Canvas & Surface Hierarchy'));
    expect(_rules, contains('0xFFFAF7F2'));
    expect(_rules, contains('0xFFEFE8E0'));
  });

  test('the canvas is the warm cream the rules name, not the theme default',
      () {
    expect(_source, contains('Color(0xFFFAF7F2)'));
    expect(
      _source,
      contains('backgroundColor: _canvas'),
      reason: 'the Scaffold should take the canvas token',
    );
  });

  test('cards are white with the one soft border', () {
    expect(_source, contains('Color(0xFFEFE8E0)'));
    expect(_source, contains('border: Border.all(color: _cardBorder)'));
    expect(_source, contains('color: Colors.white'));
  });

  test('every category eyebrow is crimson, not the section accent', () {
    // Four eyebrows in four colours is the rainbow the rules rule out.
    expect(_source, contains('Color(0xFFDD0D22)'));
    expect(_source, contains('color: _crimson'));
    expect(
      _source.contains('color: accent,\n                        letterSpacing: 1.1'),
      isFalse,
      reason: 'an eyebrow must not take the section accent',
    );
  });

  test('the accent appears on circular badges and nowhere else', () {
    // Tinted circles only. Not the card surface, not the chip, not the
    // chevron -- all three of which used to carry it.
    expect(
      _source.contains('border: Border.all(color: accent'),
      isFalse,
      reason: 'an accent border is the rainbow the rules rule out',
    );
    expect(
      _source.contains('accent: accent'),
      isFalse,
      reason: 'the card surface must not be tinted by the section accent',
    );

    // Every tint is on something round.
    final tints = RegExp(r'withValues\(alpha: 0\.12\)').allMatches(_source);
    expect(tints, isNotEmpty);
    for (final tint in tints) {
      final after = _source.substring(
        tint.end,
        (tint.end + 160).clamp(0, _source.length),
      );
      expect(after, contains('BoxShape.circle'),
          reason: 'a tint that is not a badge: ...${after.split('\n').first}');
    }
  });

  test('the chevron is muted, not an accent highlight', () {
    expect(_source, contains('Icons.chevron_right_rounded'));
    expect(
      RegExp(r'Icons\.chevron_right_rounded[^)]*color: accent')
          .hasMatch(_source),
      isFalse,
      reason: 'a chevron is a direction, not a highlight',
    );
  });

  test('the studio opens with its own quiet framing', () {
    // Not a fourth dashboard: a room. The reflection, the eyebrows and the
    // recent list all sit on the canvas; only the four tiles are cards.
    //
    // The greeting that used to open this page -- the "Studio & mindfulness"
    // eyebrow, "Your quiet space, <name>." and the line under it -- was
    // removed on request, so the page now opens on today's reflection.
    expect(_source.contains('Your quiet space,'), isFalse);
    expect(_source.contains("_buildEyebrow('Studio & mindfulness')"), isFalse);

    expect(_source, contains("_buildEyebrow(\"Today's reflection\")"));
    expect(_source, contains("_buildEyebrow('Explore')"));
    expect(_source, contains('_buildStudioGrid'));
  });

  test("today's reflection is chosen from what is known, not at random", () {
    // It changes with whether anything has been written, when it was last
    // written and the time of day -- and never asserts a feeling the app has
    // no way of knowing.
    expect(_source, contains('_reflectionPrompt'));
    expect(_source, contains('daysSince'));
    expect(_source, contains('dayOfYear % set.length'),
        reason: 'date-seeded rotation within the chosen set');
    expect(_source.contains('Random()'), isFalse,
        reason: 'a prompt that differs on every rebuild is not a reflection');
  });

  test('the recent list is real, or it is absent', () {
    // No seeded placeholders: an account that has done nothing in the studio
    // gets no section, rather than three rows pretending it has a history.
    expect(_source, contains('_recentItems()'));
    expect(_source, contains('if (_recentItems().isNotEmpty)'));
    expect(_source, contains('_latestEntry'));
  });

  test('no accent is a pastel', () {
    // The rules: "bold, punchy, and vibrant (never dull or pastel)". The
    // Recovery badge was #FF9B9E, which at a 12% tint is barely a badge.
    final accents = RegExp(r"'accent': Color\(0x([0-9A-Fa-f]{8})\)")
        .allMatches(_source)
        .map((m) => m[1]!)
        .toList();
    expect(accents, hasLength(4), reason: 'one accent per studio area');

    for (final hex in accents) {
      final colour = Color(int.parse(hex, radix: 16));
      final hsl = HSLColor.fromColor(colour);
      expect(hsl.saturation, greaterThan(0.5), reason: '#$hex is washed out');
      expect(hsl.lightness, lessThan(0.65), reason: '#$hex is a pastel');
      // And each one is from the table in the rules document.
      expect(
        _rules.toUpperCase().contains(hex.substring(2).toUpperCase()),
        isTrue,
        reason: '#$hex is not in the accent table',
      );
    }
  });

  test('the four accents are distinct', () {
    final accents = RegExp(r"'accent': Color\(0x([0-9A-Fa-f]{8})\)")
        .allMatches(_source)
        .map((m) => m[1]!.toUpperCase())
        .toSet();
    expect(accents, hasLength(4), reason: 'two areas sharing a badge colour');
  });

  test('the eyebrows sit on the canvas, not in cards', () {
    // The rule that stops a run of cards reading as a settings list. The
    // greeting it used to check is gone; the eyebrows and the reflection are
    // what carry it now.
    expect(_source.contains('_buildStudioGreeting'), isFalse);
    expect(_source, contains('_buildEyebrow'));
    expect(_source, contains('cormorantGaramond'));
  });

  test('body text is the warm muted grey, not black', () {
    expect(_source, contains('Color(0xFF7A6B72)'));
    expect(_source, contains('color: _mutedText'));
  });
}
