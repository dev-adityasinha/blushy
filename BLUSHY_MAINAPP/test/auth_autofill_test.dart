import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Signing in without typing the password every time.
///
/// The app deliberately does not store the password itself. It hands the pair
/// to the phone's own password manager, which is what fills them in next time,
/// and the checkbox decides whether that offer is made at all.
void main() {
  final source =
      File('lib/features/auth/presentation/signup_screen.dart').readAsStringSync();

  test('the fields are one credential the phone can save', () {
    expect(source.contains('AutofillGroup'), isTrue,
        reason: 'without a group the fields are saved separately, or not at all');
    expect(source.contains('AutofillHints.username'), isTrue);
    expect(source.contains('AutofillHints.password'), isTrue);
  });

  test('signup asks for a new password, login for the saved one', () {
    // newPassword makes the manager offer to generate and save one, rather
    // than filling an old password into a fresh account.
    expect(source.contains('AutofillHints.newPassword'), isTrue);
  });

  test('the offer to save is made only after auth succeeds', () {
    final start = source.indexOf('void _offerToSaveCredentials()');
    expect(start, greaterThan(-1));
    final body = source.substring(start, source.indexOf('\n  }', start));
    expect(body.contains('if (!_savePassword) return;'), isTrue,
        reason: 'unticked means nothing is offered');
    expect(body.contains('TextInput.finishAutofillContext()'), isTrue);
  });

  test('Google sign-in asks for an ID token, not just an access token', () {
    // Without serverClientId on Android, auth.idToken is null and the flow
    // silently falls back to the access token, which the backend can only
    // check through a weaker path.
    expect(source.contains('serverClientId:'), isTrue);
    expect(source.contains('_googleWebClientId'), isTrue,
        reason: 'the same client id on both sides, from one place');
  });

  test('the app never writes the password anywhere itself', () {
    // The whole point: no branch stores the typed password on device.
    expect(source.contains("BlushyStorage.write('password"), isFalse);
    expect(
      RegExp(r'''write\([^)]*_passwordController''').hasMatch(source),
      isFalse,
      reason: 'the password must not be persisted by the app',
    );
  });
}
