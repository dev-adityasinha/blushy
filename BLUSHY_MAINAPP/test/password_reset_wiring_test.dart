import 'dart:io';

import 'package:blushy_life_app/features/auth/presentation/email_auth_flow.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Forgot password?" has to actually ask for a reset.
///
/// The link on the sign-in screen showed "Password reset link sent to your
/// email." and sent nothing. A dead link is a bug; one that says it worked is
/// worse, because the person waits for an email that was never coming and does
/// not think to try again.
///
/// The flow behind it was already complete and unreachable from here:
/// `requestPasswordResetCode` posts to `/auth/send-password-reset-code`, and
/// `resetPassword` posts to `/auth/reset-password`.
void main() {
  final signupScreen =
      File('lib/features/auth/presentation/signup_screen.dart').readAsStringSync();
  final apiAuth =
      File('lib/services/api_auth_service.dart').readAsStringSync();

  test('the link no longer claims to have sent an email', () {
    expect(
      signupScreen.contains('Password reset link sent to your email.'),
      isFalse,
      reason: 'it sent nothing, so it must not say it did',
    );
  });

  test('the link opens the flow that requests one', () {
    expect(signupScreen.contains('AuthMode.forgotPassword'), isTrue,
        reason: 'the link must reach the reset flow');
    expect(signupScreen.contains('initialEmail:'), isTrue,
        reason: 'the address she just typed should carry across');
  });

  test('both steps reach the endpoints the server exposes', () {
    // authRoutes.js mounts these two.
    expect(apiAuth.contains("'/auth/send-password-reset-code'"), isTrue,
        reason: 'step one must request a code');
    expect(apiAuth.contains("'/auth/reset-password'"), isTrue,
        reason: 'step two must set the new password');
  });

  test('the reset request carries what the server validates', () {
    // emailAuthService.resetPasswordWithEmail reads all four.
    for (final field in const [
      "'email':",
      "'code':",
      "'newPassword':",
      "'confirmPassword':",
    ]) {
      expect(apiAuth.contains(field), isTrue,
          reason: '$field is required by the reset endpoint');
    }
  });

  Widget host(String? email) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmailAuthFlow(
          initialMode: AuthMode.forgotPassword,
          initialEmail: email,
          onBackToWelcome: () {},
        ),
      );

  testWidgets('the flow opens on the address it was given', (tester) async {
    await tester.pumpWidget(host('her@example.com'));
    await tester.pumpAndSettle();

    expect(find.text('her@example.com'), findsOneWidget,
        reason: 'she should not have to type it twice');
  });

  testWidgets('an empty address leaves the field empty rather than blank-filling',
      (tester) async {
    await tester.pumpWidget(host('   '));
    await tester.pumpAndSettle();

    final field = tester.widgetList<TextField>(find.byType(TextField));
    expect(field.every((f) => (f.controller?.text ?? '').isEmpty), isTrue);
  });
}
