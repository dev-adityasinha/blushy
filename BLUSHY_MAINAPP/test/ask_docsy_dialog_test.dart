import 'package:blushy_life_app/core/state.dart';
import 'package:blushy_life_app/core/storage.dart';
import 'package:blushy_life_app/features/home/home_screen.dart';
import 'package:blushy_life_app/features/sia/sia_screen.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// The article dialog's button hands her to Docsy with the question shown
/// as hers. It used to fetch a web-search summary into the dialog and, when
/// that failed, show a made-up one.
void main() {
  useIsolatedStorage();

  setUp(() {
    AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
    BlushyStorage.write('user_profile.json', {'profile': {'lifeStage': 'pregnancy'}});
  });

  Widget host(Widget dialog) => BlushyOSProvider(
        notifier: BlushyOSState(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showDialog(context: context, builder: (_) => dialog),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('the button says Ask Docsy, not Deep Dive', (tester) async {
    await tester.pumpWidget(host(const ArticleDetailDialog(
      title: 'Development this week',
      summary: 'Notes will appear here once reviewed.',
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Docsy'), findsOneWidget);
    expect(find.textContaining('Deep Dive'), findsNothing);
    expect(find.textContaining('Web Search'), findsNothing);
  });

  testWidgets('tapping it opens Docsy with the question as her message', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(host(const ArticleDetailDialog(
      title: 'Development this week',
      summary: 'Notes will appear here once reviewed.',
      question: 'What is happening in week 21 of my pregnancy?',
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask Docsy'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ArticleDetailDialog), findsNothing, reason: 'the dialog closed');
    expect(find.byType(BlushySiaScreen), findsOneWidget, reason: 'Docsy opened');
    expect(find.text('What is happening in week 21 of my pregnancy?'), findsOneWidget,
        reason: 'her question is in the thread');
    // Docsy's screen runs a placeholder timer (cancelled in dispose) and its
    // dispose kicks off one further sync. Tear it down here and pump past
    // that, the way the other Docsy tests do, so nothing is left pending.
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    while (tester.takeException() != null) {}
  });
}
