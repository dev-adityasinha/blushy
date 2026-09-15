import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Changing life stage has to go through the server.
///
/// The backend carries a real state machine for this. Sensitive moves are
/// marked `requiresConfirmation` — into pregnancy, into menopause, pregnancy
/// to postpartum — because the spec says they must never be inferred silently.
/// There is also a separate guard that refuses to re-enter pregnancy after a
/// loss without an explicit confirmation.
///
/// The settings switcher bypassed all of it: it consulted a client-side
/// conflict engine, wrote the new stage into local storage, and never called
/// `/life-stage/transition`. So the rules did not apply, the change lived on
/// one device, and the server carried on serving content, safety rules and
/// dashboards for the stage she had just left.
void main() {
  final card = File(
    'lib/features/home/widgets/life_stage_selector_card.dart',
  ).readAsStringSync();

  test('the selector asks the server before changing anything', () {
    expect(card.contains('LifeStageApi.transition'), isTrue,
        reason: 'the server state machine is what enforces the transition rules');
  });

  test('local state is only written after the server agrees', () {
    // Writing first is what let the account and the screen disagree.
    final localWrite = card.indexOf('osState.setActiveLifeStages');
    final serverCall = card.indexOf('transitionLifeStage(');
    expect(serverCall, greaterThan(-1));
    expect(serverCall, lessThan(localWrite),
        reason: 'the transition must be attempted before local state moves');
    expect(RegExp(r'if \(!(moved|outcome\.moved)\) return;').hasMatch(card), isTrue,
        reason: 'a refused transition must stop, not fall through');
  });

  test('a confirmation-required move asks the user and repeats the call', () {
    // The server answers with requiresConfirmation rather than refusing
    // outright; consent is the user's to give.
    expect(card.contains("requiresConfirmation"), isTrue);
    expect(RegExp(r'transition\(\s*toStage:[^)]*confirmed:\s*true').hasMatch(card), isTrue,
        reason: 'after she agrees, the call is repeated with her confirmation');
  });

  test('the backend still marks the sensitive transitions', () {
    // If these lose their flag the client dialog becomes decoration.
    final stages = File('backend/src/domain/lifeStages.js').readAsStringSync();
    for (final pair in ['POSTPARTUM', 'PREGNANCY']) {
      expect(stages.contains(pair), isTrue);
    }
    expect(
      RegExp(r'to:\s*LIFE_STAGES\.POSTPARTUM,\s*requiresConfirmation:\s*true')
          .hasMatch(stages),
      isTrue,
      reason: 'moving to postpartum must never be inferred silently',
    );
  });
}
