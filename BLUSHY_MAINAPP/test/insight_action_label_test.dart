import 'package:blushy_life_app/services/api_contract_client.dart';
import 'package:blushy_life_app/shared/api_state_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The button under an insight that has nothing to show yet.
///
/// `empty` and `insufficientData` are different situations and the card already
/// said so in its messages -- but both branches read the same action label, so
/// someone who had checked in today was told to "log your first check-in".
void main() {
  Widget harness(ApiResult<List<String>> result) {
    return MaterialApp(
      home: Scaffold(
        body: ApiStateCard<List<String>>(
          result: result,
          emptyMessage: 'Nothing noticed yet.',
          insufficientDataMessage: 'Once you have logged a few days.',
          emptyActionLabel: 'Log your first check-in',
          insufficientDataActionLabel: "Log today's check-in",
          onEmptyAction: () {},
          builder: (context, data) => Text(data.join()),
        ),
      ),
    );
  }

  testWidgets('nothing logged at all still asks for a first check-in',
      (tester) async {
    await tester.pumpWidget(harness(
      const ApiResult<List<String>>(state: ApiState.empty),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Log your first check-in'), findsOneWidget);
  });

  testWidgets('having logged, but not enough days, does not say "first"',
      (tester) async {
    await tester.pumpWidget(harness(
      const ApiResult<List<String>>(state: ApiState.insufficientData),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Log today's check-in"), findsOneWidget);
    expect(find.text('Log your first check-in'), findsNothing,
        reason: 'the user has already logged one');
    // The message itself was never wrong, and should be untouched.
    expect(find.text('Once you have logged a few days.'), findsOneWidget);
  });

  testWidgets('a caller that sets only one label keeps the old behaviour',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ApiStateCard<List<String>>(
          result: const ApiResult<List<String>>(state: ApiState.insufficientData),
          insufficientDataMessage: 'Not enough yet.',
          emptyActionLabel: 'Ask her to share',
          onEmptyAction: () {},
          builder: (context, data) => Text(data.join()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ask her to share'), findsOneWidget);
  });
}
