import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/shared/api_state_card.dart';

/// An empty state should say what to do next, not only that there is nothing.
///
/// A brand-new account has no logs, so every data-driven card on the home page
/// renders its empty message. `ApiStateCard` has taken an `emptyActionLabel`
/// and `onEmptyAction` from the start — and of nine usages across the app,
/// **none** supplied one. So the first thing a new user saw was a column of
/// cards reporting absence with no way forward.
Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('an empty card offers the action that would fill it', (tester) async {
    var tapped = 0;

    await tester.pumpWidget(_host(
      ApiStateCard<List<String>>(
        result: const ApiResult<List<String>>(state: ApiState.empty),
        emptyMessage: 'Nothing logged yet.',
        emptyActionLabel: 'Log your first check-in',
        onEmptyAction: () => tapped++,
        builder: (context, data) => const SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet.'), findsOneWidget);
    expect(find.text('Log your first check-in'), findsOneWidget);

    await tester.tap(find.text('Log your first check-in'));
    await tester.pumpAndSettle();
    expect(tapped, 1, reason: 'the action must actually run');
  });

  testWidgets('"not enough data yet" offers it too', (tester) async {
    // Distinct from empty: she has logged something, just not enough to say
    // anything honestly. Both states leave her waiting, so both get a step.
    await tester.pumpWidget(_host(
      ApiStateCard<List<String>>(
        result: const ApiResult<List<String>>(state: ApiState.insufficientData),
        insufficientDataMessage: 'A few more days of logs and patterns appear.',
        emptyActionLabel: 'Log your first check-in',
        onEmptyAction: () {},
        builder: (context, data) => const SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Log your first check-in'), findsOneWidget);
  });

  testWidgets('a card with real data shows the data, not the prompt', (tester) async {
    await tester.pumpWidget(_host(
      ApiStateCard<List<String>>(
        result: const ApiResult<List<String>>(state: ApiState.ready, data: ['a pattern']),
        emptyMessage: 'Nothing logged yet.',
        emptyActionLabel: 'Log your first check-in',
        onEmptyAction: () {},
        builder: (context, data) => Text(data.first),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('a pattern'), findsOneWidget);
    expect(find.text('Log your first check-in'), findsNothing);
  });

  test('the home dashboard supplies empty actions, not just messages', () {
    // The regression this guards is the original state: the parameter exists
    // and is simply never passed.
    final source = File(
      'lib/features/home/presentation/stages/everyday_wellness_dashboard.dart',
    ).readAsStringSync();

    final cards = 'ApiStateCard<'.allMatches(source).length;
    final actions = 'emptyActionLabel'.allMatches(source).length;

    expect(cards, greaterThan(0), reason: 'the dashboard state cards moved');
    expect(
      actions,
      greaterThan(0),
      reason: 'every data-driven card on home renders empty for a new account; '
          'at least some must offer a way forward',
    );
  });
}
