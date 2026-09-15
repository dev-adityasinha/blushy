import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/shared/user_display_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Three stage dashboards greeted every user as "nithya" and a fourth as
/// "Ananya", because they read the stored profile under `name` and
/// `profile.name` while onboarding writes `profile.preferredName`. The lookup
/// missed every time and fell through to the literal.
///
/// These check the resolution order and, above all, that a name is never
/// invented when none is known.
void main() {
  // Storage in a directory unique to this suite, cleared between tests.
  useIsolatedStorage();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // BlushyStorage namespaces writes per user and refuses them with no
    // session, so the stored-profile cases need one.
    // Order matters: BlushyStorage.clearUserData() also drops the auth
    // session, and storage refuses private writes without one -- so reset the
    // profile by overwriting it rather than by clearing.
    AuthStorage.saveSession(
      token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true,
    );
    BlushyStorage.clearMemoryCache();
  });

  /// Renders the helper and returns what it resolved to.
  Future<String> resolve(
    WidgetTester tester, {
    String? contextName,
    String fallback = 'there',
    bool firstNameOnly = false,
  }) async {
    final state = BlushyOSState();
    if (contextName != null) {
      state.updatePersonalContext(
        state.personalContext.copyWith(userName: contextName),
      );
    }

    String? seen;
    await tester.pumpWidget(
      BlushyOSProvider(
        notifier: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              seen = firstNameOnly
                  ? userFirstName(context, fallback: fallback)
                  : userDisplayName(context, fallback: fallback);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    // BlushyOSState's constructor kicks off a backend sync; without this the
    // test ends with that request's timer still pending.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(seen, isNotNull, reason: 'the builder never ran');
    return seen!;
  }

  testWidgets('prefers the name held in app state', (tester) async {
    expect(await resolve(tester, contextName: 'Meera'), 'Meera');
  });

  testWidgets('falls back to the key onboarding actually writes', (tester) async {
    // profile.preferredName -- the one the old code never looked at.
    BlushyStorage.write('user_profile.json', {
      'profile': {'preferredName': 'Nithya'},
    });
    expect(await resolve(tester), 'Nithya');
  });

  testWidgets('still reads the older top-level keys', (tester) async {
    BlushyStorage.write('user_profile.json', {'name': 'Priya'});
    expect(await resolve(tester), 'Priya');
  });

  testWidgets('invents nothing when no name is known', (tester) async {
    expect(await resolve(tester), 'there');
  });

  testWidgets('an empty stored name is not a name', (tester) async {
    BlushyStorage.write('user_profile.json', {
      'profile': {'preferredName': '   '},
    });
    expect(await resolve(tester), 'there');
  });

  testWidgets('the "Blushy User" placeholder is never greeted', (tester) async {
    expect(await resolve(tester, contextName: 'Blushy User'), 'there');
  });

  testWidgets('leading punctuation is stripped, not rendered', (tester) async {
    // Would otherwise read "Good morning, , Meera".
    expect(await resolve(tester, contextName: ', Meera'), 'Meera');
  });

  testWidgets('the caller chooses the form of address', (tester) async {
    // Pregnancy and postpartum address the user as "mama" -- an endearment,
    // not a guess at who she is.
    expect(await resolve(tester, fallback: 'mama'), 'mama');
  });

  testWidgets('state wins over the stored profile', (tester) async {
    BlushyStorage.write('user_profile.json', {
      'profile': {'preferredName': 'Stale'},
    });
    expect(await resolve(tester, contextName: 'Fresh'), 'Fresh');
  });

  testWidgets('userFirstName takes only the first word', (tester) async {
    expect(
      await resolve(tester, contextName: 'Meera Sharma', firstNameOnly: true),
      'Meera',
    );
  });
}
