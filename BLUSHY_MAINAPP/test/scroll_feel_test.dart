import 'package:blushy_life_app/shared/scroll_feel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The small confirmation you get when a list runs out.
///
/// The parts worth pinning are the ones that would be irritating rather than
/// broken: buzzing every frame while resting at the bottom, or buzzing as a
/// horizontal row of chips is flicked past its end.
void main() {
  late List<String> haptics;

  setUp(() {
    haptics = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String? ?? '');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host({Axis axis = Axis.vertical}) => MaterialApp(
        home: Scaffold(
          body: ScrollEndHaptic(
            child: ListView.builder(
              scrollDirection: axis,
              itemCount: 30,
              itemBuilder: (context, index) => SizedBox(
                height: 100,
                width: 100,
                child: Text('row $index'),
              ),
            ),
          ),
        ),
      );

  testWidgets('reaching the end taps once', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(haptics, isEmpty, reason: 'nothing on open');

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 4000);
    await tester.pumpAndSettle();

    expect(haptics, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('resting at the end does not keep tapping', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 4000);
    await tester.pumpAndSettle();
    // A second push while already at the bottom.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(haptics, hasLength(1));
  });

  testWidgets('a horizontal row stays silent', (tester) async {
    // Chip rows and carousels hit their end constantly while being flicked.
    await tester.pumpWidget(host(axis: Axis.horizontal));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(-4000, 0), 4000);
    await tester.pumpAndSettle();

    expect(haptics, isEmpty);
  });

  test('scrolling bounces on every platform, with no glow over it', () {
    // Android clamps by default, which reads as the app locking for a frame.
    const behaviour = BlushyScrollBehavior();
    expect(behaviour.getScrollPhysics(_FakeContext()),
        isA<BouncingScrollPhysics>());
  });
}

class _FakeContext extends StatelessWidget implements BuildContext {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
