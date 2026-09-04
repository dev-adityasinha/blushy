import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// The soft scene behind the top of a screen.
///
/// A tinted wash with a couple of slow curves in it, fading into
/// [BlushyColors.background] before the content gets going. The join is the
/// whole point: the last stop is exactly the page colour, so there is no line
/// where the scene stops and the page starts.
///
/// Painted rather than shipped as an image so it takes any tint, costs nothing
/// in the bundle, and stays crisp at any screen size.
class HomeBackdrop extends StatelessWidget {
  const HomeBackdrop({
    super.key,
    this.tint,
    this.height = 420,
    required this.child,
  });

  /// The colour at the very top. Defaults to the brand blush.
  final Color? tint;

  /// How far down the wash reaches before it has fully become the page.
  final double height;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BackdropPainter(tint: tint ?? BlushyColors.secondary),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.tint});

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;

    // Ends on the page colour exactly, so the wash disappears into it rather
    // than stopping at a visible edge.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(tint, Colors.white, 0.35)!,
            Color.lerp(tint, BlushyColors.background, 0.72)!,
            BlushyColors.background,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    // Two long curves across the wash. Kept very low contrast: this sits
    // behind text, and anything stronger competes with it.
    void curve(double startY, double controlY, double endY, double alpha) {
      final path = Path()
        ..moveTo(0, size.height * startY)
        ..quadraticBezierTo(
          size.width * 0.55,
          size.height * controlY,
          size.width,
          size.height * endY,
        )
        ..lineTo(size.width, 0)
        ..lineTo(0, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    curve(0.62, 0.34, 0.52, 0.22);
    curve(0.34, 0.60, 0.24, 0.16);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.tint != tint;
}
