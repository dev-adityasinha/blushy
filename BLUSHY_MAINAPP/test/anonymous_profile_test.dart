import 'package:blushy_life_app/features/community/user_profile_sheet.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// Tapping the author of an anonymous post.
///
/// An anonymous post carries an empty authorId, so the lookup was always going
/// to come back empty and the sheet said "Failed to load profile details" --
/// which reads as the app breaking rather than as the poster having chosen not
/// to be named.
Widget _host(String userId) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UserProfileSheet(userId: userId)),
    );

void main() {
  useIsolatedStorage();

  testWidgets('an anonymous author is explained, not reported as a failure',
      (tester) async {
    await withTestImages(() async {
      await tester.pumpWidget(_host(''));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.textContaining('posted anonymously'), findsOneWidget);
      expect(find.textContaining('chose not to be named'), findsOneWidget);
      expect(find.text('Failed to load profile details.'), findsNothing);
    });
  });

  testWidgets('a real lookup that fails still says so', (tester) async {
    // The honest error is kept for the case it was written for.
    await withTestImages(() async {
      await tester.pumpWidget(_host('someone-real'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.text('Failed to load profile details.'), findsOneWidget);
      expect(find.textContaining('posted anonymously'), findsNothing);
    });
  });
}
