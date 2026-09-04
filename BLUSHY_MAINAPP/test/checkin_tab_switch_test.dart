import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/presentation/stages/everyday_wellness_dashboard.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// A check-in answer has to reach the device, not only the server.
///
/// The selector wrote the value to the backend and nowhere else, while the
/// dashboard restores these fields from `daily_checkin.json` on every reload —
/// and changing tabs causes a reload. So the file still held the previous
/// answer and put it straight back.
///
/// The answer is given on the symptoms sheet now rather than on an inline
/// check-in selector, so this drives it through the sheet. The race it guards
/// is unchanged: what is written on save must survive the dashboard being
/// rebuilt from nothing.
void main() {
  useIsolatedStorage();

  setUp(() {
    // Taller than the 800x600 default. The dashboard and the sheet are both
    // lazy scrollables, so only what fits is built and `find.text` cannot see
    // the rest.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(800, 6000);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    // Storage is namespaced per user and silently no-ops without a session,
    // so every fixture below would be discarded without this.
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
        'goals': ['Reduce cramps & discomfort'],
        'answers': {
          'symptoms': ['Cramps', 'Fatigue'],
          'goals': ['Reduce cramps & discomfort'],
        },
      },
    });
  });

  Widget host() => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EverydayWellnessDashboard(stageKey: 'reproductiveYears'),
          ),
        ),
      );

  /// Opens the sheet from the check-in and answers Pain with "Mild".
  ///
  /// 'Mild' is unique to the pain group at this stage: the other groups that
  /// offer it (hot flashes, night sweats, brain fog, joint pain) are
  /// perimenopause and menopause only.
  Future<void> answerPainMild(WidgetTester tester) async {
    // In through the Pain row of Today's Logged Signals, which opens the
    // sheet. The check-in's "Nothing logged yet" prompt used to be the way in,
    // but with pain already stored the check-in no longer says nothing was
    // logged -- correctly -- so that prompt is not on the page.
    //
    // ensureVisible rather than scrollUntilVisible: on the tall test surface
    // the row is already built, and scrollUntilVisible then scrolls past it.
    final painLabel = find.text('Pain').first;
    await tester.ensureVisible(painLabel);
    await tester.pump();

    await tester.tap(painLabel, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mild'), warnIfMissed: false);
    await tester.pump();

    await tester.tap(find.textContaining('Save'), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('the summary shows the answer she gave, not the old one',
      (tester) async {
    // What the device already holds. This is the value that kept coming back.
    BlushyStorage.write('daily_checkin.json', {
      'pain': 'Severe',
      'date': DateTime.now().toIso8601String(),
    });

    await withTestImages(() async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));

      // Top of the page: "TODAY'S LOGGED SIGNALS" reads the stored answer.
      expect(find.text('Severe'), findsWidgets,
          reason: 'the stored answer should be showing to begin with');

      await answerPainMild(tester);

      // The reload a tab change causes, in its harshest form.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));
    });

    // Network calls fail under the test binding; not the subject here.
    tester.takeException();

    // Scoped to the summary's own "Pain" row rather than the whole page.
    final painRow = find.ancestor(
      of: find.text('Pain'),
      matching: find.byType(Row),
    );
    expect(painRow, findsWidgets, reason: 'the summary row should be built');
    expect(
      find.descendant(of: painRow.first, matching: find.text('Mild')),
      findsOneWidget,
      reason: 'her answer must be what the summary shows after a reload',
    );
    expect(
      find.descendant(of: painRow.first, matching: find.text('Severe')),
      findsNothing,
      reason: 'the previous answer must not come back — this is the bug',
    );
  });

  testWidgets('and the value survives the screen being rebuilt', (tester) async {
    BlushyStorage.write('daily_checkin.json', {
      'pain': 'Severe',
      'date': DateTime.now().toIso8601String(),
    });

    await withTestImages(() async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));

      await answerPainMild(tester);

      // Worst case: the dashboard is built from nothing, as it would be after
      // navigating away and back. It must come back showing her answer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 300));
    });

    tester.takeException();

    expect(BlushyStorage.read('daily_checkin.json')['pain'], 'Mild');
  });
}
