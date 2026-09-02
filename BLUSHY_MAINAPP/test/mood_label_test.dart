import 'dart:io';

import 'package:blushy_life_app/core/state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two mood pickers, and the word she taps has to be the word that is stored.
///
/// The Dr. Docsy picker sends a 1-10 level. The shared `feeling` was then
/// re-derived from that number against a *third* four-word scale
/// (Happy/Okay/Calm/Low), so the label she chose was discarded and replaced:
///
///   Tired (4) -> "Calm"      Anxious (3) -> "Low"
///   Balanced (7) -> "Okay"   Sleepy (3)  -> "Low"
///   Calm (8) -> "Happy"      Sad (2)     -> "Low"
///
/// Only "Happy" survived. The home check-in reads that shared value, which is
/// why the two screens disagreed.
void main() {
  test('the wellbeing state carries the tapped label', () {
    final wb = CurrentWellbeingState(mood: 4, moodLabel: 'Tired');
    expect(wb.moodLabel, 'Tired');
    expect(wb.mood, 4, reason: 'the score is still kept for charting');
  });

  test('a bare number does not keep a label that no longer describes it', () {
    final source = File('lib/core/state.dart').readAsStringSync();
    expect(
        source.contains(
            'moodLabel: moodLabel ?? (mood != null ? null : _wellbeingState.moodLabel)'),
        isTrue,
        reason: 'a stale label must not outrank the reading that replaced it');
  });

  test('the stored feeling prefers her word over the derived one', () {
    final source = File('lib/core/state.dart').readAsStringSync();

    expect(source.contains('String? feelingStr = wb.moodLabel;'), isTrue,
        reason: 'her own word first');
    expect(source.contains('if (feelingStr == null && wb.mood != null) {'), isTrue,
        reason: 'the thresholds remain, but only for a mood set as a number');

    // The old unconditional derivation is what replaced her answer.
    expect(source.contains('if (wb.mood != null) {\n        if (wb.mood! >= 8) {'),
        isFalse);
  });

  test('the Dr. Docsy picker sends the label', () {
    final sia = File('lib/features/sia/sia_screen.dart').readAsStringSync();
    expect(RegExp(r'updateWellbeing\(\s*mood: level,\s*moodLabel: label').hasMatch(sia),
        isTrue,
        reason: 'without this the number is all that survives the tap');
  });
}
