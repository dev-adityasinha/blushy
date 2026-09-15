import 'dart:io';

import 'package:blushy_life_app/features/partner/pending_invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shareable invite link was broken at both ends.
///
/// The server handed out `https://blushy.life/partner/claim#code=<token>`.
/// That host is a plain static host with no single-page rewrite, so
/// `/partner/claim` answered 404 -- verified against the live site -- and the
/// build it does serve at `/` is a different, older package than the one
/// shipping now. The recipient never reached an app, so nothing could claim
/// anything.
///
/// And had they reached one, the app would still have dropped the code.
/// `MaterialApp` runs its navigator with `reportsRouteUpdateToEngine: true`,
/// so `pushReplacementNamed('/onboarding/women')` and then
/// `pushReplacementNamed('/home')` rewrite the browser URL through the default
/// hash strategy. The partner screen read `Uri.base.fragment` when it mounted
/// -- after all of that -- and by then the fragment said `/home`.
void main() {
  group('the code is read from the launch URL', () {
    setUp(PendingInviteCode.debugReset);

    const token =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('a link the server now issues carries a usable code', () {
      expect(
        PendingInviteCode.parse(
          Uri.parse('https://blushy-web-upload.vercel.app/#code=$token'),
        ),
        token,
      );
    });

    test('the old shape still parses, so live links keep working', () {
      // Codes handed out before this change point at /partner/claim. They
      // cannot be opened there, but a recipient who retypes the host should
      // not also be defeated by the parser.
      expect(
        PendingInviteCode.parse(
          Uri.parse('https://example.com/partner/claim#code=$token'),
        ),
        token,
      );
    });

    test('a route fragment is not mistaken for one', () {
      // What the hash strategy leaves behind after onboarding.
      for (final fragment in ['/home', '/onboarding/women', '/']) {
        expect(
          PendingInviteCode.parse(Uri.parse('https://example.com/#$fragment')),
          isNull,
          reason: fragment,
        );
      }
    });

    test('and neither is a truncated one', () {
      expect(
        PendingInviteCode.parse(Uri.parse('https://example.com/#code=abc123')),
        isNull,
      );
      expect(PendingInviteCode.parse(Uri.parse('https://example.com/')), isNull);
    });

    test('clearing it stops a second claim', () {
      expect(PendingInviteCode.hasCode, isFalse);
      PendingInviteCode.captureFromLaunchUrl();
      PendingInviteCode.clear();
      expect(PendingInviteCode.code, isNull);
    });
  });

  group('it is captured before anything can navigate', () {
    late final String main;

    setUpAll(() {
      main = File('lib/main.dart').readAsStringSync();
    });

    test('main() reads it, and does so before runApp', () {
      final capture = main.indexOf('PendingInviteCode.captureFromLaunchUrl();');
      expect(capture, greaterThan(-1), reason: 'the launch URL is never read');

      final run = main.indexOf('runApp(');
      expect(capture, lessThan(run),
          reason: 'the first named route would have overwritten it by then');
    });
  });

  group('the partner screen claims what was captured', () {
    late final String screen;

    setUpAll(() {
      screen = File('lib/features/partner/partner_screen.dart').readAsStringSync();
    });

    test('it no longer reads the URL itself', () {
      final start = screen.indexOf('void _checkUrlFragmentClaim()');
      expect(start, greaterThan(-1));

      final body = screen.substring(start, start + 600);
      expect(body, contains('PendingInviteCode.code'));
      expect(body.contains('Uri.base.fragment'), isFalse,
          reason: 'by the time this runs the fragment is a route path');
    });

    test('a refused code is spent and a timed-out one is not', () {
      // Render's free instance pays a cold start of up to ~27s. Clearing the
      // code on that would leave a link that can never be redeemed.
      expect(screen, contains('const spent = {400, 403, 409};'));
      expect(screen, contains("spent.contains(res['statusCode'] as int?)"));
    });

    test('the service reports the status it was refused with', () {
      final service =
          File('lib/services/api_partner_service.dart').readAsStringSync();
      final start = service.indexOf('Future<Map<String, dynamic>> acceptInviteLink');
      expect(start, greaterThan(-1));

      final body = service.substring(start, start + 900);
      expect(body, contains("'statusCode': e.response?.statusCode"));
    });
  });

  group('the server builds a link that resolves', () {
    late final String controller;
    late final String code;

    String stripComments(String source) => source
        .split(String.fromCharCode(10))
        .where((line) => !line.trimLeft().startsWith('//'))
        .join(String.fromCharCode(10));

    setUpAll(() {
      controller = stripComments(
        File('backend/src/controllers/partnerController.js').readAsStringSync(),
      );
      // Comments stripped on both: the files explain what the dead URL was,
      // and saying so there is the point rather than a relapse.
      code = stripComments(
        File('backend/src/utils/inviteUrl.js').readAsStringSync(),
      );
    });

    test('it no longer points at a 404', () {
      for (final source in [code, controller]) {
        expect(source.contains('blushy.life/partner/claim'), isFalse,
            reason: 'that path answers 404 on the host it names');
      }
    });

    test('the code sits at the root, in the fragment', () {
      expect(code, contains(r'`${resolveInviteBaseUrl()}/#code=${token}`'));
      expect(controller, contains('inviteUrl: buildInviteUrl(token)'));
    });

    test('and the host is configurable without a code change', () {
      expect(code, contains('env.partnerInviteBaseUrl'));

      final env = File('backend/src/utils/env.js').readAsStringSync();
      expect(env, contains("process.env.PARTNER_INVITE_BASE_URL"));
    });

    test('a base that cannot be opened by somebody else is refused', () {
      final start = code.indexOf('function resolveInviteBaseUrl()');
      expect(start, greaterThan(-1));

      final body = code.substring(start, code.indexOf('\n}', start));
      // http://localhost:8095 is what APP_PUBLIC_URL holds locally, and it is
      // useless in a link the recipient opens on their own device.
      expect(body, contains(r'/^https:\/\/[^\s/]+$/i'));
      expect(body, contains('DEFAULT_INVITE_BASE_URL'));
    });
  });
}
