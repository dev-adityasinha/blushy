import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The scene behind Today's Cycle.
///
/// Big overlapping circles in the app's own red, washing down into
/// [BlushyColors.background] before the section ends. The joins are the point:
/// the wash dissolves into the page colour at the bottom *and* at both sides,
/// so it has no edge anywhere and reads as part of the page rather than as a
/// panel on it.
///
/// This is what replaced the white card with a border. Painted rather than an
/// image, so it takes the theme colour and stays crisp at any width.
class CycleCardBackdrop extends StatelessWidget {
  const CycleCardBackdrop({
    super.key,
    this.tint,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    required this.child,
  });

  /// The colour the wash is drawn in. The app's primary by default.
  final Color? tint;

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // No clip and no radius. A rounded corner would draw the outline of a card,
    // which is the thing this replaced.
    return CustomPaint(
      painter: _CycleBackdropPainter(tint: tint ?? BlushyColors.primary),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CycleBackdropPainter extends CustomPainter {
  _CycleBackdropPainter({required this.tint});

  final Color tint;

  /// The strongest the wash gets, at the very top.
  ///
  /// Mostly page colour with the theme red mixed in: the red at full strength
  /// is a signal colour, and text has to stay readable on this.
  static const double _topStrength = 0.20;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    const page = BlushyColors.background;

    Color wash(double strength) => Color.lerp(page, tint, strength)!;

    // Down the section: the tint at the top, the page colour by the bottom.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // A short ramp in at the very top rather than starting on full
            // tint. The section is usually the first thing in the scroll, and
            // a hard line across the top reads as a band rather than as the
            // page's own colour.
            wash(_topStrength * 0.55),
            wash(_topStrength),
            wash(_topStrength * 0.70),
            wash(_topStrength * 0.20),
            page,
          ],
          stops: const [0, 0.10, 0.45, 0.80, 1],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRect(rect);

    // Circles far bigger than the section, so only their edges cross it --
    // which is what makes them read as sweeping curves rather than as circles.
    void blob(double cx, double cy, double r, double strength) {
      canvas.drawCircle(
        Offset(size.width * cx, size.height * cy),
        size.width * r,
        Paint()..color = wash(strength),
      );
    }

    blob(-0.18, 0.62, 0.82, _topStrength * 1.45);
    blob(1.08, 0.06, 0.66, _topStrength * 1.20);
    blob(0.42, 1.28, 0.90, _topStrength * 0.55);

    // The blobs are drawn over the gradient, so the lowest one carries tint
    // back down into the foot the gradient had already cleared. Fading out to
    // the page colour again afterwards is what makes the bottom join exact
    // rather than three-parts-in-255 short of it.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [page.withValues(alpha: 0), page],
          stops: const [0.74, 1],
        ).createShader(rect),
    );

    // And out to the page colour at both sides, so there is no vertical edge
    // where the wash stops. Without this the section still reads as a card,
    // just one without a border.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [page, page.withValues(alpha: 0), page.withValues(alpha: 0), page],
          stops: const [0, 0.13, 0.87, 1],
        ).createShader(rect),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CycleBackdropPainter old) => old.tint != tint;
}
