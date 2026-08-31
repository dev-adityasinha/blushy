import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/home_screen.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The dashboard's State holds every check-in selection, and the set recording
/// which ones she has just edited. If a sync recreates that State, all of it is
/// lost and the guards protecting it are pointless — the set they consult is
/// brand new.
///
/// Driven against the real `BlushyHomeScreen`, not a reduced Column: the earlier
/// reduction preserved State and told us nothing about the real tree.
void main() {
  useIsolatedStorage();

  testWidgets('the dashboard keeps its State across a sync', (tester) async {
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );
    BlushyStorage.write('user_profile.json', {
      'profile': {
        'lifeStage': 'reproductiveYears',
        'symptoms': ['Cramps', 'Fatigue'],
        'answers': {'symptoms': ['Cramps', 'Fatigue']},
      },
    });

    final state = BlushyOSState();

    await withTestImages(() async {
      await tester.pumpWidget(
        BlushyOSProvider(
          notifier: state,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BlushyHomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final before = tester.state(find.byType(EverydayWellnessDashboard));

      // What a tab change does: the sync starts, isSyncing flips, and the
      // banner appears above the dashboard.
      state.syncStateWithBackend();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final after = tester.state(find.byType(EverydayWellnessDashboard));

      expect(identical(before, after), isTrue,
          reason: 'a recreated State would lose every check-in selection and '
              'empty the set that records what she just edited');
    });

    tester.takeException();
  });
}
