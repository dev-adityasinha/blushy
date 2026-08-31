import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Today's context" must show what she picked.
///
/// The check-in offers words — High/Medium/Low for energy, and
/// Happy/Okay/Cramps/Tired/Irritable for mood — and stores the label next to a
/// score kept for charting. The Dr. Docsy cards read only the score, so
/// choosing "High" was displayed as "Level 2/10": a number she was never shown,
/// on a scale she was never given.
///
/// The home page had always preferred the label; only this screen did not.
void main() {
  final source =
      File('lib/features/sia/sia_screen.dart').readAsStringSync();

  test('the cards prefer the stored label over the score', () {
    expect(
        RegExp(r'final String energyText = savedEnergy\.isNotEmpty\s*\?\s*savedEnergy')
            .hasMatch(source),
        isTrue,
        reason: 'energy must show her chosen option first');

    expect(
        RegExp(r'final String moodText = savedMood\.isNotEmpty\s*\?\s*savedMood')
            .hasMatch(source),
        isTrue,
        reason: 'mood must show her chosen option first');
  });

  test('the score survives as a fallback, not as the answer', () {
    // Someone who logged through a path that records only a score should still
    // see something rather than "Not Logged".
    expect(source.contains(r'"Level ${wb.energy}/10"'), isTrue,
        reason: 'the score is still the fallback');
    expect(source.contains(r'"Level ${wb.mood}/10"'), isTrue);
  });

  test('the label is read from the same file the home page uses', () {
    expect(
        source.contains("BlushyStorage.read('daily_checkin.json')"), isTrue,
        reason: 'reading a different source would let the two screens disagree');
    expect(source.contains("(checkin['feeling'] ?? checkin['mood'])"), isTrue,
        reason: 'the mood is stored under both keys depending on the path');
  });

  test('the mood emoji matches the options the picker offers', () {
    // While the card showed "Level 4/10" none of these could match, so every
    // mood drew the same face.
    for (final key in const ['happy', 'okay', 'cramp', 'tired', 'irrit']) {
      expect(source.contains('moodKey.contains("$key")'), isTrue,
          reason: '$key is a mood the picker offers');
    }
  });
}
