import 'package:blushy_life_app/shared/voice_note_bottom_sheet.dart';
import 'package:blushy_life_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The Voice Reflection sheet.
///
/// Record, transcribe, save. The save path writes through JournalQuickEntry
/// into the store the journal actually reads; it used to call a method whose
/// only reader was in the dead lib/presentation/ tree, so a reflection was
/// written and then shown nowhere.
Widget _host({Size size = const Size(390, 844)}) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: VoiceNoteBottomSheet()),
        ),
      ),
    );

void main() {
  useIsolatedStorage();

  testWidgets('the sheet lays out without overflowing', (tester) async {
    await withTestImages(() async {
      await tester.pumpWidget(_host());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Voice Reflection'), findsOneWidget);
    });
  });

  testWidgets('it still fits on a narrow phone', (tester) async {
    // "Save Reflection" and "Re-record" were each sized to their own label in
    // a spaceBetween row, so together they ran past the card.
    await withTestImages(() async {
      await tester.pumpWidget(_host(size: const Size(320, 700)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
