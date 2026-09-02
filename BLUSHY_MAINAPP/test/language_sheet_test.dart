import 'dart:io';

import 'package:blushy_life_app/shared/header.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';
import 'helpers/test_image_http.dart';

/// The language chip in the header.
///
/// It drives `MaterialApp.locale`, so it changes the whole app. The sheet said
/// the opposite — "the rest of the app stays in English" — which was true
/// before the app itself was localised and stale afterwards.
void main() {
  useIsolatedStorage();

  test('the sheet describes what it actually changes', () {
    final source = File('lib/shared/header.dart').readAsStringSync();

    expect(source.contains("'App language'"), isTrue);
    expect(source.contains('Docsy speaks'), isFalse);
    expect(source.contains('The rest of the app stays in English'), isFalse,
        reason: 'it changes MaterialApp.locale, so that was untrue');
    expect(source.contains('Changes the language across the app'), isTrue);
  });

  test('the sheet can hold every language it offers', () {
    // Seven languages plus a heading overflowed a half-height sheet.
    final source = File('lib/shared/header.dart').readAsStringSync();
    expect(source.contains('isScrollControlled: true'), isTrue);
    expect(source.contains('SingleChildScrollView'), isTrue);
  });

  testWidgets('opening it lists the languages without overflowing',
      (tester) async {
    AuthStorage.saveSession(
      token: 'test-token',
      userId: 'test-user',
      email: 'a@b.c',
      role: 'woman',
      onboardingCompleted: true,
    );

    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await withTestImages(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(appBar: BlushyHeader()),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.language_rounded));
      await tester.pumpAndSettle();

      expect(find.text('App language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
