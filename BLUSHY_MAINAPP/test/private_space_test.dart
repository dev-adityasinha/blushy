import 'package:blushy_life_app/features/partner/private_space.dart';
import 'package:blushy_life_app/features/partner/presentation/private_space_partner_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Private Space, and the promise it has to keep.
///
/// Argument Mode was a boolean on her own device. It never reached the server,
/// and its only effect was to filter Docsy cards out of her own messenger --
/// her partner kept receiving her cycle, mood and sleep the entire time. A
/// screen that said otherwise would have been a privacy lie, which is the
/// worst kind of bug this feature could carry.
///
/// So the pause is now the permission matrix, which the server enforces. What
/// these pin is the part that could quietly go wrong: that the keys switched
/// off are the personal ones, that resuming restores exactly what was on
/// rather than a default, and that the snapshot survives a restart.

void main() {
  useIsolatedStorage();

  test('it pauses the personal keys, and only those', () {
    // Messages, blooms, gifts and shared memories are not permission-gated,
    // which is what lets the connection stay open while updates pause.
    expect(PrivateSpace.pausedKeys, contains('shareMood'));
    expect(PrivateSpace.pausedKeys, contains('shareCycle'));
    expect(PrivateSpace.pausedKeys, contains('shareSleep'));
    expect(PrivateSpace.pausedKeys, contains('shareInsights'));

    // His two keys must NOT be here, and this assertion used to say the
    // opposite -- it pinned the bug rather than the behaviour.
    //
    // `allowAiSuggestionsMan` and `allowDecoderMan` belong to his side of the
    // connection. The server refuses any patch containing a key that is not
    // the caller's to set, and refuses the *whole* patch, so including them
    // meant none of her four were paused either. Private space came back 403
    // every time and the button looked like it did nothing.
    //
    // Nothing is lost: both drive suggestions computed from the four keys
    // above, so pausing those leaves them nothing to read.
    expect(PrivateSpace.pausedKeys, isNot(contains('allowAiSuggestionsMan')));
    expect(PrivateSpace.pausedKeys, isNot(contains('allowDecoderMan')));

    // Who she is, rather than how she is today. Pausing it would blank his
    // sense of her stage rather than her current state.
    expect(PrivateSpace.pausedKeys, isNot(contains('shareOnboarding')));

    // And never her own side of the AI.
    expect(PrivateSpace.pausedKeys, isNot(contains('allowAiSuggestionsWoman')));

    // Everything it pauses is hers to pause.
    for (final key in PrivateSpace.pausedKeys) {
      expect(key.startsWith('share'), isTrue, reason: '$key is not a sharing key');
    }
  });

  test('nothing is private space until it is turned on', () {
    expect(PrivateSpace.stateFor('c1'), isNull);
  });

  test('the record keeps what to put back, not a default', () {
    // The failure this guards: resuming with DEFAULT_PERMISSIONS would turn
    // on sharing she had never agreed to, which is worse than leaving it off.
    final state = PrivateSpaceState(
      active: true,
      startedAt: DateTime.now(),
      until: null,
      note: null,
      restore: const {'shareMood': true, 'shareCycle': false},
    );

    final restored = PrivateSpaceState.fromJson(state.toJson());
    expect(restored.restore['shareMood'], isTrue);
    expect(restored.restore['shareCycle'], isFalse);
    expect(restored.active, isTrue);
  });

  test('a timed space reports what is left; an open one says so', () {
    final timed = PrivateSpaceState(
      active: true,
      startedAt: DateTime.now(),
      until: DateTime.now().add(const Duration(hours: 2, minutes: 14)),
      note: null,
      restore: const {},
    );
    expect(timed.remainingLabel, contains('2h'));
    expect(timed.remaining, isNotNull);

    final open = PrivateSpaceState(
      active: true,
      startedAt: DateTime.now(),
      until: null,
      note: null,
      restore: const {},
    );
    expect(open.remainingLabel, 'Until you resume');
    expect(open.remaining, isNull);
  });

  test('a record that will not decode restores nothing rather than throwing',
      () {
    // A corrupted value must not take the portal down. She can set her
    // sharing again; a crash on open is not recoverable from inside the app.
    final broken = PrivateSpaceState.fromJson({
      'active': true,
      'startedAt': 'not a date',
      'restore': 'not json',
    });
    expect(broken.restore, isEmpty);
    expect(broken.active, isTrue);
  });

  test('an empty note is treated as no note', () {
    // She is never made to explain, so "nothing for now" must not arrive at
    // her partner as an empty quotation mark.
    final state = PrivateSpaceState.fromJson({
      'active': true,
      'note': '   ',
      'restore': '{}',
    });
    expect(state.note, isNull);
  });

  testWidgets('the partner is told calmly, and not invited to investigate',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrivateSpacePartnerState(partnerName: 'Anaya'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A LITTLE SPACE'), findsOneWidget);
    expect(find.textContaining('Anaya is taking some time'), findsOneWidget);
    expect(find.textContaining("You don't need to do anything"), findsOneWidget);

    // None of the words that turn a boundary into an incident.
    for (final wrong in ['Argument', 'No data', 'Error', 'Why']) {
      expect(find.textContaining(wrong), findsNothing, reason: wrong);
    }

    // Doing nothing is offered as a real choice, not a disabled button.
    expect(find.text('Give her space'), findsOneWidget);
  });

  testWidgets('her note is shown alone, never beside her health data',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrivateSpacePartnerState(
            partnerName: 'Anaya',
            note: 'I just need some space.',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('I just need some space.'), findsOneWidget);
    for (final leak in ['Day ', 'Luteal', 'Mood', 'Energy', 'Sleep']) {
      expect(find.textContaining(leak), findsNothing, reason: leak);
    }
  });

  testWidgets('with no note, nothing is quoted', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrivateSpacePartnerState(partnerName: 'Anaya'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('“'), findsNothing);
  });
}
