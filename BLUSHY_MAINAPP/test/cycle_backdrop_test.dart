import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blushy_life_app/shared/cycle_card_backdrop.dart';
import 'package:blushy_life_app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wash that has no edges.
///
/// It was the background of the home tab's cycle section until that section
/// was rebuilt to the mockup, where the cycle is a tinted hero card instead.
/// The widget is kept and kept tested because what it does is the hard part
/// and is not written down anywhere else: a tint that dissolves into the page
/// colour on three sides, so it reads as part of the page rather than as a
/// panel laid on it.
///
/// A flat fill with a hard edge is a card. These are the tests that tell the
/// difference.
void main() {
  testWidgets('it is the theme red at the top and the page colour at its edges',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: BlushyColors.background,
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 360,
              height: 420,
              child: CycleCardBackdrop(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // One image, sampled many times: a second toImage in the same test hangs.
    late Uint32List pixels;
    // Taken from the image rather than assumed. The boundary is captured at
    // whatever ratio the test view is on, and indexing a 3x image by logical
    // width silently samples the wrong part of the picture.
    var stride = 360;
    var rows = 420;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      stride = image.width;
      rows = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      pixels = data!.buffer.asUint32List();
    });

    /// Samples in fractions of the image, so it reads the same at any ratio.
    Color at(double fx, double fy) {
      final x = (fx * (stride - 1)).round();
      final y = (fy * (rows - 1)).round();
      final abgr = pixels[y * stride + x];
      return Color.fromARGB(
        (abgr >> 24) & 0xFF,
        abgr & 0xFF,
        (abgr >> 8) & 0xFF,
        (abgr >> 16) & 0xFF,
      );
    }

    const page = BlushyColors.background;

    // The red is there, and it is the app's red rather than some other one:
    // the top is pulled towards primary on every channel.
    final top = at(0.5, 0.015);
    expect(top.r, lessThan(page.r), reason: 'a red tint darkens the top');
    expect(top.b, lessThan(page.b - 0.02),
        reason: 'and pulls blue down hardest, which is what makes it red');
    expect(top.g, lessThan(page.g));

    // And it is a wash, not a fill: the section stays readable under text.
    expect(top.b, greaterThan(BlushyColors.primary.b + 0.5),
        reason: 'nowhere near full-strength primary');

    // The three joins. Each has to land on the page colour exactly, or the
    // section has an edge there and reads as a card again.
    void expectPage(Color c, String where) {
      expect((c.r - page.r).abs(), lessThan(0.01), reason: 'red at $where');
      expect((c.g - page.g).abs(), lessThan(0.01), reason: 'green at $where');
      expect((c.b - page.b).abs(), lessThan(0.01), reason: 'blue at $where');
    }

    expectPage(at(0.5, 1), 'the foot');
    expectPage(at(0, 0.33), 'the left edge');
    expectPage(at(1, 0.33), 'the right edge');

    // Between the edge and the middle it has to actually be tinted, or the
    // side fade has eaten the whole thing.
    expect(at(0.5, 0.25).b, lessThan(page.b - 0.02));
  });

  testWidgets('it takes a tint', (tester) async {
    // The default is the brand red, but the widget is not hardcoded to it --
    // which is what lets a second section use it without a second copy.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 200,
          child: CycleCardBackdrop(
            tint: Color(0xFF0000FF),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<CycleCardBackdrop>(find.byType(CycleCardBackdrop)).tint,
      const Color(0xFF0000FF),
    );
  });
}
