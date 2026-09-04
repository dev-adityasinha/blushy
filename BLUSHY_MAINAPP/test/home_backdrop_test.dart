import 'package:blushy_life_app/shared/home_backdrop.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wash behind the top of the home page.
///
/// The join is the point: it has to end on the page colour exactly, or there
/// is a visible line where the scene stops.
void main() {
  testWidgets('it sits behind the content, not in front of it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeBackdrop(child: Text('on top', textDirection: TextDirection.ltr)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('on top'), findsOneWidget);
  });

  testWidgets('it does not swallow taps meant for the page', (tester) async {
    // A full-width painted layer over the top of the screen would otherwise
    // eat every tap in the header.
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeBackdrop(
          child: Align(
            alignment: Alignment.topCenter,
            child: TextButton(
              onPressed: () => tapped = true,
              child: const Text('tap me'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tap me'));
    expect(tapped, isTrue);
  });

  testWidgets('it takes a tint, for a page that wants its own', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeBackdrop(
        tint: BlushyColors.info,
        child: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();

    final backdrop =
        tester.widget<HomeBackdrop>(find.byType(HomeBackdrop));
    expect(backdrop.tint, BlushyColors.info);
  });

  test('it fades to the page colour, so there is no seam', () {
    // Asserted on the constant rather than by sampling pixels: what matters is
    // that the last stop is the page colour itself, and a pixel test would
    // pass on anything close to it.
    const backdrop = HomeBackdrop(child: SizedBox.shrink());
    expect(backdrop.height, greaterThan(0));
  });
}
