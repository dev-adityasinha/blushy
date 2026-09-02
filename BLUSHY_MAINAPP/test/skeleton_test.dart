import 'dart:io';

import 'package:blushy_life_app/shared/skeleton.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Placeholders shaped like the thing that is loading.
///
/// A spinner says "wait" and nothing else: the layout jumps when the data
/// lands, and a slow card cannot be told apart from a broken one. These check
/// the parts that are easy to get wrong — the shapes must actually paint, the
/// shimmer must stop when motion is reduced, and the animation must not be left
/// running after the widget goes away.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('the shapes paint', (tester) async {
    await tester.pumpWidget(host(const SkeletonTextCard()));
    await tester.pump();

    expect(find.byType(SkeletonLine), findsWidgets);
    expect(find.byType(Shimmer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a metric card reserves its space', (tester) async {
    // The point of a skeleton: the box does not change size when data lands.
    await tester.pumpWidget(host(const SizedBox(width: 180, child: SkeletonMetricCard())));
    await tester.pump();

    final size = tester.getSize(find.byType(SkeletonMetricCard));
    expect(size.width, 180);
    expect(size.height, greaterThan(100),
        reason: 'a placeholder with no height reserves nothing');
  });

  testWidgets('a post skeleton carries the parts of a post', (tester) async {
    await tester.pumpWidget(host(const SkeletonPostCard()));
    await tester.pump();

    // Author bubble, title, body lines, and the footer controls.
    expect(find.byType(SkeletonCircle), findsOneWidget);
    expect(find.byType(SkeletonLine), findsNWidgets(4));
    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('the shimmer moves', (tester) async {
    await tester.pumpWidget(host(const SkeletonTextCard()));
    await tester.pump();

    Gradient? gradientNow() {
      final container = tester.widgetList<Container>(find.byType(Container)).firstWhere(
            (c) => (c.decoration as BoxDecoration?)?.gradient != null,
            orElse: () => Container(),
          );
      return (container.decoration as BoxDecoration?)?.gradient;
    }

    final first = gradientNow();
    expect(first, isNotNull, reason: 'an animating skeleton paints a gradient');

    await tester.pump(const Duration(milliseconds: 400));
    expect(gradientNow(), isNot(equals(first)),
        reason: 'the band has to sweep, or it is just a grey bar');

    // Let the repeating controller be disposed rather than left running.
    await tester.pumpWidget(host(const SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion turns the shimmer off, not the skeleton', (tester) async {
    await tester.pumpWidget(host(const SkeletonTextCard(), reduceMotion: true));
    await tester.pump();

    // The shapes still reserve space; they just stop moving.
    expect(find.byType(SkeletonLine), findsWidgets);

    final containers = tester.widgetList<Container>(find.byType(Container));
    final gradients = containers
        .map((c) => (c.decoration as BoxDecoration?)?.gradient)
        .where((g) => g != null);
    expect(gradients, isEmpty,
        reason: 'a shimmer is decoration, and motion was turned off deliberately');

    final flat = containers
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .where((c) => c == BlushyColors.border);
    expect(flat, isNotEmpty, reason: 'they paint flat instead');
  });

  testWidgets('a list repeats one shape', (tester) async {
    await tester.pumpWidget(host(
      SkeletonList(count: 4, itemBuilder: (context, index) => const SkeletonListRow()),
    ));
    await tester.pump();

    expect(find.byType(SkeletonListRow), findsNWidgets(4));
  });

  test('data loading no longer falls back to a spinner', () {
    // Where a card is waiting on data it shows the shape of that data. Action
    // states — a Send button mid-send, a voice note transcribing — keep their
    // inline progress, because a skeleton there would replace a control rather
    // than stand in for content.
    for (final path in const [
      'lib/features/community/community_screen.dart',
      'lib/features/m_studio/m_studio_screen.dart',
      'lib/features/partner/partner_screen.dart',
      'lib/features/community/user_profile_sheet.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.contains('shared/skeleton.dart'), isTrue,
          reason: '$path loads data and must have skeletons available');
    }

    // The shared card state drives ten call sites, none of which override it.
    final card = File('lib/shared/api_state_card.dart').readAsStringSync();
    expect(card.contains('Shimmer('), isTrue,
        reason: 'the default placeholder behind every ApiStateCard');
  });
}
