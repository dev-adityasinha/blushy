import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A bouquet sent to a partner has to be visible to them.
///
/// The backend has carried both halves for a while: `sendMyBouquet` writes a
/// row for the recipient, and `GET /bouquets?received=true` lists it. The
/// client fetched that list on every account sync and exposed it as
/// `receivedBouquets` — and no screen ever read the property. So a bouquet
/// arrived, was stored, was loaded into memory, and was never shown to the
/// person it was sent to.
void main() {
  final garden = File(
    'lib/features/partner/digibouquet/screens/garden_screen.dart',
  ).readAsStringSync();

  test('the garden renders what the partner sent', () {
    expect(garden.contains('state.receivedBouquets'), isTrue,
        reason: 'the received list must reach a screen, not just the state');
    expect(garden.contains("_currentTab == 'received'"), isTrue,
        reason: 'and it needs a tab to reach it through');
  });

  test('the tab row is not hidden from someone who has only received', () {
    // It was gated on having saved a bouquet, which hid the partner's gift
    // from anyone who had never made one themselves.
    expect(RegExp(r'if \(hasSaved \|\| hasReceived\)').hasMatch(garden), isTrue,
        reason: 'a recipient with no bouquets of their own must still see the tabs');
  });

  test('ordering is not derived from an identifier', () {
    // 'Most liked' ranked by a number computed from the id: comm_1 became 21
    // likes, comm_2 became 35. Nothing anywhere counts likes.
    expect(garden.contains("replaceAll('comm_', '')"), isFalse,
        reason: 'a like count parsed out of an id is invented');
  });

  test('the state still fetches both lists', () {
    final state = File(
      'lib/features/partner/digibouquet/state/bouquet_state.dart',
    ).readAsStringSync();

    expect(state.contains('BouquetsApi.list(received: true)'), isTrue);
    expect(state.contains('_receivedBouquets'), isTrue);
  });
}
