import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Dr. Docsy tab no longer carries a community section.
///
/// It rendered a "Community Discussion" card at the foot of the chat that
/// pushed the community screen, plus an unreachable `rich: 'community'` card.
/// The Community tab itself is untouched — this is about the Dr. Docsy tab not
/// duplicating it.
void main() {
  final sia = File('lib/features/sia/sia_screen.dart').readAsStringSync();

  test('no community section remains in the Dr. Docsy screen', () {
    expect(sia.toLowerCase().contains('community'), isFalse,
        reason: 'the Dr. Docsy tab must not link to or describe the community');
    expect(sia.contains('Tap to join the discussion'), isFalse);
    expect(sia.contains('Tap to read the discussion'), isFalse);
  });

  test('the code that only served it is gone too', () {
    // Each of these was reachable only through the removed section, so leaving
    // them would be dead weight the analyzer would flag on the next change.
    for (final symbol in const [
      '_buildJournalContinuousSection',
      '_showJournalPromptSheet',
      'VoiceNoteBottomSheet',
    ]) {
      expect(sia.contains(symbol), isFalse, reason: '$symbol was left behind');
    }
  });

  test('the Community tab itself still exists', () {
    // The failure mode of over-removing here is deleting the feature rather
    // than the duplicate entry point into it.
    final shell = File('lib/features/home/blushy_shell.dart').readAsStringSync();
    expect(shell.contains('BlushyCommunityScreen'), isTrue);

    expect(File('lib/features/community/community_screen.dart').existsSync(), isTrue);
  });
}
