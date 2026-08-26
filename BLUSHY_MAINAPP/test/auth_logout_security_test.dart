import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:blushy_life_app/features/auth/presentation/choose_experience_screen.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  group('Logout & Experience Screen Security Tests', () {
    setUp(() {
      AuthStorage.clearSession();
    });

    testWidgets('ChooseExperienceScreen has clear button label and leaves user unauthenticated', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool selectedForMe = false;
      bool selectedPartner = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChooseExperienceScreen(
            onSelectForMe: () => selectedForMe = true,
            onSelectPartner: () => selectedPartner = true,
          ),
        ),
      );

      // Verify the button text is "Select & Proceed to Sign In"
      expect(find.text('Select & Proceed to Sign In'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);

      // Initially disabled
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Select & Proceed to Sign In');
      ElevatedButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);

      // Tap "For Me" card
      await tester.tap(find.text('For Me'), warnIfMissed: false);
      await tester.pumpAndSettle();

      button = tester.widget(buttonFinder);
      expect(button.onPressed, isNotNull);

      // Tap "Select & Proceed to Sign In"
      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(selectedForMe, isTrue);
      expect(selectedPartner, isFalse);

      // Verify AuthStorage is still unauthenticated
      expect(AuthStorage.getToken(), isNull);
    });

    test('BlushyOSState.logout() completely clears all auth, profile, and onboarding cache', () async {
      // 1. Seed dummy user session and cache
      AuthStorage.saveSession(
        token: 'mock_access_token',
        refreshToken: 'mock_refresh_token',
        userId: 'user_12345',
        email: 'test@example.com',
        role: 'woman',
        onboardingCompleted: true,
      );

      BlushyStorage.write('user_profile.json', {'profile': {'userName': 'Test User'}});
      BlushyStorage.write('user_onboarding_answers.json', {'answers': {'cycle_length': 28}});

      expect(AuthStorage.getToken(), equals('mock_access_token'));
      expect(BlushyStorage.read('user_profile.json').isNotEmpty, isTrue);
      expect(BlushyStorage.read('user_onboarding_answers.json').isNotEmpty, isTrue);

      // 2. Initialize State and trigger logout
      final state = BlushyOSState();
      await state.logout();

      // 3. Verify all session and cache data are completely purged
      expect(state.isAuthenticated, isFalse);
      expect(state.onboardingCompleted, isFalse);
      expect(state.hasChosenExperience, isFalse);
      expect(state.selectedRole, equals('woman'));
      expect(state.journals, isEmpty);
      expect(state.siaMessages, isEmpty);

      expect(AuthStorage.getToken(), isNull);
      expect(BlushyStorage.read('user_profile.json'), isEmpty);
      expect(BlushyStorage.read('user_onboarding_answers.json'), isEmpty);
      expect(BlushyStorage.read('blushy_auth_session.json'), isEmpty);
    });
  });
}
