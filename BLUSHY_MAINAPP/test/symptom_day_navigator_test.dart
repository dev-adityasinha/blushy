import 'package:blushy_life_app/features/home/symptom_category_preference.dart';
import 'package:blushy_life_app/features/home/widgets/symptom_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isolated_storage.dart';

/// Looking back at earlier days on the symptoms sheet.
void main() {
  useIsolatedStorage();

  setUp(() => SymptomCategoryPreference.disabled.value = <String>{});

  final requested = <DateTime>[];
  Set<String> answer = {};

  Widget host({bool withHistory = true}) => MaterialApp(
        home: Scaffold(
          body: SymptomLogSheet(
            initialSelection: const {'Cramps'},
            onSave: (_) {},
            stage: 'livingWithMyCycle',
            onLoadDay: withHistory
                ? (day) async {
                    requested.add(day);
                    return answer;
                  }
                : null,
          ),
        ),
      );

  setUp(() {
    requested.clear();
    answer = {};

    // The sheet is a lazy scrollable with up to a dozen groups.
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
  });

  testWidgets('it opens on today, named rather than dated', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    // The date itself is not shown for today.
    final now = DateTime.now();
    expect(find.textContaining('${now.day} '), findsNothing);
  });

  testWidgets('the forward arrow is dead on today', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget,
        reason: 'there is nothing to log in the future');
    expect(requested, isEmpty, reason: 'and nothing to fetch');
  });

  testWidgets('back goes to yesterday and asks for that day', (tester) async {
    answer = {'Headache'};
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Yesterday'), findsOneWidget);
    expect(requested.length, 1);

    final today = DateTime.now();
    final asked = requested.single;
    expect(
      DateTime(today.year, today.month, today.day).difference(asked).inDays,
      1,
    );
    // And it shows that day, not today's selection.
    expect(find.text('Headache'), findsOneWidget);
  });

  testWidgets('a day with nothing logged says so', (tester) async {
    answer = {};
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Nothing was logged by you.'), findsOneWidget);
    // Not an empty form, which would read as a failure to load.
    expect(find.text('SYMPTOMS'), findsNothing);
  });

  testWidgets('an earlier day is shown, not edited', (tester) async {
    answer = {'Headache'};
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    // No save button: writing here would record against today.
    expect(find.textContaining('Save'), findsNothing);
    expect(find.text('This day is shown as you logged it.'), findsOneWidget);
    expect(find.text('Logged symptoms'), findsOneWidget,
        reason: 'the title stops saying "today" once it is not today');
  });

  testWidgets('coming forward again returns to today and re-enables saving',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('Save'), findsOneWidget);
    // Today's own selection is back, not the day she just looked at.
    expect(find.text("Log today's symptoms"), findsOneWidget);
  });

  testWidgets('the arrows are hidden when there is no history to load',
      (tester) async {
    // Shown doing nothing would be worse than not shown at all.
    await tester.pumpWidget(host(withHistory: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('Today'), findsNothing);
  });
}
