import 'package:blushy_life_app/features/legal/consent_gate.dart';
import 'package:blushy_life_app/services/api_consent_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The consent gate stands between a signed-in user and the whole app, so the
/// question that matters is not "does it ask when it should" but "does it ever
/// refuse to let someone in when it shouldn't".
///
/// A user who cannot reach the server, whose session has expired, or whose
/// response arrives malformed must still get to their own health data. Only a
/// definite answer saying consent is needed may block.
void main() {
  const child = Text('the app', textDirection: TextDirection.ltr);

  Widget gate(Future<ConsentStatus?> Function() check) => MaterialApp(
        home: ConsentGate(checkStatus: check, child: child),
      );

  ConsentStatus status({required bool needs, ConsentReason? reason}) => ConsentStatus(
        hasConsent: !needs,
        needsConsent: needs,
        reason: reason,
      );

  testWidgets('renders the app while the answer is still unknown', (tester) async {
    // Never completes: the first frame must already show the app rather than a
    // spinner, because the overwhelmingly common case is that consent is fine.
    // A Completer rather than a delayed future, so no timer outlives the test.
    final pending = Completer<ConsentStatus?>();
    await tester.pumpWidget(gate(() => pending.future));
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('lets the user through when consent is on record', (tester) async {
    await tester.pumpWidget(gate(() async => status(needs: false)));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('lets the user through when the server cannot be reached', (tester) async {
    // null is "unknown", never "missing".
    await tester.pumpWidget(gate(() async => null));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('lets the user through when the check throws', (tester) async {
    await tester.pumpWidget(gate(() async => throw Exception('offline')));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('asks when consent was never recorded', (tester) async {
    await tester.pumpWidget(
      gate(() async => status(needs: true, reason: ConsentReason.neverGiven)),
    );
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsNothing);
    expect(find.text('One thing before you continue'), findsOneWidget);
  });

  testWidgets('says so plainly when the documents have changed', (tester) async {
    await tester.pumpWidget(
      gate(() async => status(needs: true, reason: ConsentReason.documentsUpdated)),
    );
    await tester.pumpAndSettle();
    expect(find.text('We have updated our policies'), findsOneWidget);
  });

  testWidgets('the agree button stays disabled until all three are ticked', (tester) async {
    await tester.pumpWidget(
      gate(() async => status(needs: true, reason: ConsentReason.neverGiven)),
    );
    await tester.pumpAndSettle();

    ElevatedButton agree() => tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(agree().onPressed, isNull);

    // The label beside each box is a link that opens the document, so the box
    // is what toggles. Ticking two of the three is not enough: consent to one
    // document is not consent to another.
    await tester.tap(find.byKey(const ValueKey('consent-tick-Privacy Policy')));
    await tester.tap(find.byKey(const ValueKey('consent-tick-Terms of Service')));
    await tester.pumpAndSettle();
    expect(agree().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('consent-tick-Medical Disclaimer')));
    await tester.pumpAndSettle();
    expect(agree().onPressed, isNotNull);
  });

  group('ConsentStatus.fromJson', () {
    test('reads a complete response', () {
      final s = ConsentStatus.fromJson({
        'hasConsent': true,
        'needsConsent': false,
        'reason': null,
        'grantedAt': '2026-09-09T10:00:00.000Z',
        'acceptedVersions': {'privacy_policy': '1.0'},
      });

      expect(s.hasConsent, isTrue);
      expect(s.needsConsent, isFalse);
      expect(s.grantedAt, isNotNull);
      expect(s.acceptedVersions?['privacy_policy'], '1.0');
    });

    test('an unrecognised reason does not become "no consent needed"', () {
      final s = ConsentStatus.fromJson({'hasConsent': false, 'needsConsent': true, 'reason': '???'});
      expect(s.needsConsent, isTrue);
      expect(s.reason, ConsentReason.unknown);
    });

    test('missing fields default to not blocking', () {
      // A malformed body must not be read as "this user has not consented".
      final s = ConsentStatus.fromJson(<String, dynamic>{});
      expect(s.needsConsent, isFalse);
      expect(s.grantedAt, isNull);
    });

    test('an unparseable date is dropped rather than guessed', () {
      final s = ConsentStatus.fromJson({'hasConsent': true, 'grantedAt': 'last Tuesday'});
      expect(s.grantedAt, isNull);
    });
  });

  test('every document the client can show has a version to record', () {
    // The server refuses an acceptance that names a version it does not hold,
    // so an empty or missing entry here would make consent impossible to give.
    expect(kLegalDocumentVersions.keys.toSet(),
        {'privacy_policy', 'terms', 'medical_disclaimer'});
    for (final entry in kLegalDocumentVersions.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} has no version');
    }
  });
}
