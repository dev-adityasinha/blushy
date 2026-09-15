import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The verification code reaches her inbox, and nowhere else.
///
/// Reported with a screenshot: the signup dialog printed "Code: 810552" above
/// the six boxes, and had already typed it into them.
///
/// That makes the check ceremonial. A code proves someone owns an address
/// only because it arrives *at that address*; handing it back in the same HTTP
/// response and filling in the boxes proves nothing, and on any server that
/// returns it, it lets anyone register an address they do not control.
///
/// The server side is already right -- `EMAIL_DELIVERY_FALLBACK_ENABLED`
/// defaults to false when NODE_ENV is production, and Render has it set to
/// "false" explicitly. A development server still returns the code so somebody
/// with no mail delivery can get past the screen, and that is fine: what was
/// wrong is that the app read it and showed it whatever the server was.
void main() {
  late final String signup;
  late final String flow;
  late final String service;

  setUpAll(() {
    signup = File('lib/features/auth/presentation/signup_screen.dart').readAsStringSync();
    flow = File('lib/features/auth/presentation/email_auth_flow.dart').readAsStringSync();
    service = File('lib/services/api_auth_service.dart').readAsStringSync();
  });

  test('the app never reads the code out of the response', () {
    // The field is gone entirely, so it cannot be quietly reintroduced by a
    // screen that wants to be helpful.
    expect(service.contains('lastDispatchedCode'), isFalse);
    expect(service.contains("response.data['otp']"), isFalse);

    // Both capture sites read `['code']`; neither does now.
    expect(service.contains("final code = response.data['code']"), isFalse);
  });

  test('no screen displays a code', () {
    for (final entry in {'signup_screen': signup, 'email_auth_flow': flow}.entries) {
      expect(entry.value.contains('lastDispatchedCode'), isFalse, reason: entry.key);
      expect(entry.value.contains("'Code: "), isFalse, reason: entry.key);
    }
  });

  test('and no screen types it into the boxes', () {
    // Pre-filling is the same failure wearing a different shape: the person
    // at the keyboard never had to read the inbox.
    for (final entry in {'signup_screen': signup, 'email_auth_flow': flow}.entries) {
      expect(entry.value.contains('newCode[i]'), isFalse, reason: entry.key);
      expect(entry.value.contains('defaultCode[i]'), isFalse, reason: entry.key);
    }
  });

  test('a resend says a code was sent, without saying which', () {
    expect(flow, contains('A new verification code has been sent.'));
    // The snackbar used to interpolate the code itself.
    expect(flow.contains(r'New verification code ($newCode) sent.'), isFalse);
  });

  test('the six boxes start empty', () {
    expect(signup, contains('List.generate(6, (_) => TextEditingController())'));
  });
}
