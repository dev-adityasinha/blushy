import 'package:blushy_life_app/features/home/widgets/metric_trend_chart.dart';
import 'package:blushy_life_app/features/home/widgets/numeric_metric_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Basal temperature and weight.
///
/// Both are numbers rather than chips, and both are rejected by the server
/// outside a range. The thing worth proving is that the range is enforced
/// before the request, because a rejection on the wire shows nothing on screen.
void main() {
  double? saved;

  Widget host(NumericMetric metric,
          {double? initial, List<MetricReading> history = const []}) =>
      MaterialApp(
        home: Scaffold(
          body: NumericMetricSheet(
            metric: metric,
            initialValue: initial,
            history: history,
            onSave: (v) => saved = v,
          ),
        ),
      );

  setUp(() => saved = null);

  group('the client range matches the server', () {
    test('basal temperature', () {
      // healthEvents.js: celsius must be between 33 and 43.
      expect(NumericMetric.bbt.min, 33);
      expect(NumericMetric.bbt.max, 43);
      expect(NumericMetric.bbt.payloadKey, 'celsius');
      expect(NumericMetric.bbt.eventType, 'bbt_logged');
    });

    test('weight', () {
      // healthEvents.js: kg must be between 20 and 400.
      expect(NumericMetric.weight.min, 20);
      expect(NumericMetric.weight.max, 400);
      expect(NumericMetric.weight.payloadKey, 'kg');
      expect(NumericMetric.weight.eventType, 'weight_logged');
    });
  });

  testWidgets('a value in range saves', (tester) async {
    await tester.pumpWidget(host(NumericMetric.weight));
    await tester.enterText(find.byType(TextField), '61.4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, 61.4);
  });

  testWidgets('a value outside the range is refused here, not on the wire',
      (tester) async {
    await tester.pumpWidget(host(NumericMetric.weight));
    // A plausible mistake: pounds typed into a kilograms field. 135 lb is a
    // real weight, so the guard has to be the unit's range, not a sanity check
    // on the digits.
    await tester.enterText(find.byType(TextField), '450');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(find.textContaining('between'), findsOneWidget);
  });

  testWidgets('a value inside the range still saves', (tester) async {
    // Saving pops the sheet, so this cannot share a pump with the test above.
    await tester.pumpWidget(host(NumericMetric.weight));
    await tester.enterText(find.byType(TextField), '135');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, 135);
  });

  testWidgets('empty input says so rather than saving nothing', (tester) async {
    await tester.pumpWidget(host(NumericMetric.bbt));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(find.text('Enter a number.'), findsOneWidget);
  });

  testWidgets('a comma decimal is accepted', (tester) async {
    // Many keyboards produce one, and double.tryParse rejects it outright.
    await tester.pumpWidget(host(NumericMetric.bbt));
    await tester.enterText(find.byType(TextField), '36,55');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, 36.55);
  });

  testWidgets('the steppers move by the metric step and clamp', (tester) async {
    await tester.pumpWidget(host(NumericMetric.bbt, initial: 42.95));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, 43.0, reason: 'clamped to the maximum, not pushed past it');
  });

  group('the trend chart', () {
    testWidgets('one reading does not draw a trend', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricTrendChart(
            readings: [MetricReading(day: DateTime(2026, 9, 1), value: 36.4)],
            unit: '°C',
            decimals: 2,
          ),
        ),
      ));
      expect(find.textContaining('A trend needs a few days'), findsOneWidget);
    });

    testWidgets('the range shown is the data, not zero', (tester) async {
      // A zero-based axis would flatten a BBT shift into a straight line: the
      // whole signal lives inside one degree.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricTrendChart(
            readings: [
              MetricReading(day: DateTime(2026, 9, 1), value: 36.40),
              MetricReading(day: DateTime(2026, 9, 2), value: 36.45),
              MetricReading(day: DateTime(2026, 9, 3), value: 36.70),
            ],
            unit: '°C',
            decimals: 2,
          ),
        ),
      ));

      expect(find.text('36.40 – 36.70 °C'), findsOneWidget);
      expect(find.text('LAST 3'), findsOneWidget);
    });

    testWidgets('a flat run does not divide by zero', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricTrendChart(
            readings: [
              MetricReading(day: DateTime(2026, 9, 1), value: 60.0),
              MetricReading(day: DateTime(2026, 9, 2), value: 60.0),
            ],
            unit: 'kg',
            decimals: 1,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('60.0 – 60.0 kg'), findsOneWidget);
    });
  });
}
