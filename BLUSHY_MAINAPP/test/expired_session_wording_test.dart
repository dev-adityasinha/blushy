import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/shared/stage_empty_notice.dart';

/// An expired session must not be reported as a privacy decision.
///
/// Reported from her own home screen: "This information has not been shared
/// with you", sitting under her own greeting, about her own cycle.
///
/// Two steps got it there. `GET /period/predictions` returns 401 when the
/// session has run out, and the client mapped **401 and 403 alike** to
/// `ApiState.restricted`. That state's wording is written for Partner Mode,
/// where it is true -- she really did decline to share. `StageStateNotice` is
/// used by both sides, so her dashboard inherited the partner's sentence.
///
/// 401 and 403 are now different states, because they are different facts:
/// one is a login that ran out, the other is somebody's decision.
void main() {
  Future<void> pump(WidgetTester tester, ApiState state) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StageStateNotice(
          state: state,
          hasData: false,
          emptyMessage: 'Nothing logged yet.',
          onRetry: () {},
        ),
      ),
    ));
  }

  testWidgets('an expired session says so, and offers the way back',
      (tester) async {
    await pump(tester, ApiState.unauthenticated);

    expect(find.textContaining('Sign in again'), findsOneWidget);
    expect(find.textContaining('session has expired'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // The sentence that caused the report.
    expect(find.textContaining('has not been shared with you'), findsNothing);
  });

  testWidgets('a real privacy decision still reads as one', (tester) async {
    // Partner Mode depends on this wording being exactly what it is.
    await pump(tester, ApiState.restricted);

    expect(find.textContaining('has not been shared with you'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);
  });

  test('the two states are distinct', () {
    expect(ApiState.values, contains(ApiState.unauthenticated));
    expect(ApiState.unauthenticated, isNot(ApiState.restricted));

    const signedOut = ApiResult<String>(state: ApiState.unauthenticated);
    expect(signedOut.isUnauthenticated, isTrue);
    expect(signedOut.isRestricted, isFalse,
        reason: 'an expired login is not a decision anyone made about her');
  });

  test('401 and 403 are mapped apart wherever they are handled', () {
    // Both services returned `restricted` for either code.
    for (final path in [
      'lib/services/api_period_service.dart',
      'lib/services/api_sia_service.dart',
    ]) {
      final source = File(path).readAsStringSync();

      expect(source, contains('ApiState.unauthenticated'), reason: path);
      expect(
        source.contains('401 || res.statusCode == 403'),
        isFalse,
        reason: '$path still lumps the two together',
      );
      expect(
        source.contains('status == 401 || status == 403'),
        isFalse,
        reason: '$path still lumps the two together',
      );
    }
  });
}
