import 'dart:convert';

import 'package:blushy_life_app/features/home/widgets/real_insights_list.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/services/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/isolated_storage.dart';

/// A section scrolled off the home and back must not load again.
///
/// The home is a lazy list, so a section that leaves the screen is disposed
/// and rebuilt when it returns. "What your logs show" and "Patterns in your
/// logs" fetched on every return and showed their spinner each time, which
/// read as the page refreshing itself while scrolling.
void main() {
  useIsolatedStorage();

  testWidgets('scrolling away and back does not fetch again', (tester) async {
    AuthStorage.saveSession(token: 't', userId: 'u', email: 'a@b.c', role: 'woman', onboardingCompleted: true);
    var calls = 0;
    ApiContractClient.clientOverride = MockClient((req) async {
      calls += 1;
      return http.Response(
        jsonEncode({
          'data': [],
          'state': 'insufficient_data',
          'errorCode': 'INSUFFICIENT_DATA',
          'version': 'patterns-v1',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(() => ApiContractClient.clientOverride = null);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: const [
            RealInsightsList(title: 'What your logs show'),
            SizedBox(height: 3000),
            Text('bottom'),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
    expect(find.text('Not enough logged yet to find a pattern'), findsOneWidget);

    // Far enough for the list to drop the section, then back.
    controller.jumpTo(2800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls, 1, reason: 'kept alive: no second request, no second spinner');
    expect(find.text('Not enough logged yet to find a pattern'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
