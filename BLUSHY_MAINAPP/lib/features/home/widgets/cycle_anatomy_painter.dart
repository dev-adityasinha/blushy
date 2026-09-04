import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// The uterus illustration on the home card, with the cycle traced over it.
///
/// Replaces the stroked outline the card used to draw. That one was a single
/// bezier line whose *stroke* was the progress bar; this is a filled anatomical
/// drawing, so progress rides on a separate guide path laid over the artwork.
///
/// Drawn rather than shipped as an image on purpose: the card's box is much
/// wider than it is tall, and a bitmap of a square illustration either squashes
/// or crops. Vectors just fit.
class CycleAnatomyPainter extends CustomPainter {
  CycleAnatomyPainter({
    required this.progress,
    this.cycleLength = 28,
    this.periodLength = 5,
    this.showCycle = true,
  });

  /// How far through the cycle, 0..1.
  final double progress;
  final int cycleLength;
  final int periodLength;

  /// Whether to trace the cycle along the tubes.
  ///
  /// Off where the cycle is drawn as a ring around the picture instead, so
  /// the same day is not marked in two places.
  final bool showCycle;

  // The illustration's own palette.
  static const Color _body = Color(0xFFF2A2BE);
  static const Color _bodyLight = Color(0xFFF7B9CE);
  static const Color _cavity = Color(0xFFE87FA6);
  static const Color _ovaryFill = Color(0xFFFFFFFF);

  // The cycle phases, as on the old painter so the legend still matches.
  static const Color _menstrual = Color(0xFFEF4444);
  static const Color _follicular = Color(0xFFF97316);
  static const Color _ovulation = Color(0xFFFACC15);
  static const Color _luteal = BlushyColors.accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // The drawing is authored square. Fit it inside whatever box the card
    // gives us and centre it, so it never distorts.
    final double side = math.min(size.width, size.height);
    final double dx = (size.width - side) / 2;
    final double dy = (size.height - side) / 2;
    double x(double v) => dx + v * side;
    double y(double v) => dy + v * side;
    Offset p(double a, double b) => Offset(x(a), y(b));

    _paintTubes(canvas, side, x, y);
    _paintBody(canvas, x, y);
    _paintOvaries(canvas, side, p);
    if (showCycle) _paintCycle(canvas, side, x, y);
  }

  /// The uterus, cervix and canal as one continuous filled shape.
  void _paintBody(Canvas canvas, double Function(double) x, double Function(double) y) {
    final path = Path()
      ..moveTo(x(0.300), y(0.175))
      // Fundus: the rounded dome across the top.
      ..cubicTo(x(0.300), y(0.045), x(0.700), y(0.045), x(0.700), y(0.175))
      // Right wall tapering to the cervix.
      ..cubicTo(x(0.694), y(0.340), x(0.592), y(0.435), x(0.574), y(0.540))
      // Canal down to a rounded tip.
      ..cubicTo(x(0.566), y(0.700), x(0.560), y(0.850), x(0.500), y(0.935))
      ..cubicTo(x(0.440), y(0.850), x(0.430), y(0.700), x(0.426), y(0.540))
      // Left wall back up to the horn.
      ..cubicTo(x(0.408), y(0.435), x(0.306), y(0.340), x(0.300), y(0.175))
      ..close();
    canvas.drawPath(path, Paint()..color = _body);

    // The endometrial cavity: an inverted triangle from the horns to the
    // cervix, then the thread of the canal. This is the shape the reference
    // draws in a deeper pink -- not the white flecks, which are gone.
    final cavity = Path()
      ..moveTo(x(0.418), y(0.190))
      ..cubicTo(x(0.452), y(0.310), x(0.484), y(0.410), x(0.494), y(0.515))
      ..lineTo(x(0.506), y(0.515))
      ..cubicTo(x(0.516), y(0.410), x(0.548), y(0.310), x(0.582), y(0.190))
      ..cubicTo(x(0.545), y(0.245), x(0.455), y(0.245), x(0.418), y(0.190))
      ..close();
    canvas.drawPath(cavity, Paint()..color = _cavity.withValues(alpha: 0.42));

    // A soft highlight on the dome, which is what gives the reference its
    // two-tone look rather than reading as a flat silhouette.
    final highlight = Path()
      ..moveTo(x(0.380), y(0.150))
      ..cubicTo(x(0.400), y(0.090), x(0.600), y(0.090), x(0.620), y(0.150))
      ..cubicTo(x(0.560), y(0.120), x(0.440), y(0.120), x(0.380), y(0.150))
      ..close();
    canvas.drawPath(highlight, Paint()..color = _bodyLight);
  }

  /// The fallopian tubes and the fimbriae they end in, mirrored either side.
  void _paintTubes(Canvas canvas, double side, double Function(double) x, double Function(double) y) {
    final tube = Paint()
      ..color = _body
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.038
      ..strokeCap = StrokeCap.round;

    for (final bool isLeft in [true, false]) {
      // Mirror by reflecting x about the centre line.
      double mx(double v) => x(isLeft ? v : 1 - v);

      canvas.drawPath(
        Path()
          ..moveTo(mx(0.320), y(0.150))
          ..cubicTo(mx(0.300), y(0.085), mx(0.215), y(0.070), mx(0.150), y(0.110))
          ..cubicTo(mx(0.120), y(0.128), mx(0.100), y(0.145), mx(0.090), y(0.165)),
        tube,
      );

      // Fimbriae: the short fringe at the open end, three strokes fanned out.
      final fringe = Paint()
        ..color = _cavity
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.022
        ..strokeCap = StrokeCap.round;
      const List<double> angles = [-0.55, 0.0, 0.55];
      for (final double a in angles) {
        final Offset origin = Offset(mx(0.090), y(0.165));
        final double base = isLeft ? math.pi : 0.0;
        final double len = side * 0.055;
        canvas.drawLine(
          origin,
          origin + Offset(math.cos(base + a) * len, math.sin(base + a) * len),
          fringe,
        );
      }
    }
  }

  /// The ovaries: pale ellipses tucked under each tube.
  void _paintOvaries(Canvas canvas, double side, Offset Function(double, double) p) {
    for (final bool isLeft in [true, false]) {
      final Offset centre = p(isLeft ? 0.175 : 0.825, 0.235);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(isLeft ? -0.25 : 0.25);
      final Rect r = Rect.fromCenter(
        center: Offset.zero,
        width: side * 0.150,
        height: side * 0.100,
      );
      canvas.drawOval(r, Paint()..color = _ovaryFill);
      canvas.drawOval(
        r,
        Paint()
          ..color = _body
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.016,
      );
      canvas.restore();
    }
  }

  /// The part that moves: phase colour filling along the anatomy, and the egg
  /// riding the front of it.
  ///
  /// The guide path is the journey the old painter drew -- up one side, out to
  /// a fimbria, around the ovary, across the fundus and down the other side --
  /// re-laid over this artwork so the phase maths carries over untouched.
  void _paintCycle(Canvas canvas, double side, double Function(double) x, double Function(double) y) {
    // Traces the drawn anatomy itself: in at one fimbria, along that tube,
    // down the uterus wall, under the cervix, and back out the other side.
    // No loops and no retracing, so the colour reads as filling the outline
    // rather than drawing on top of it.
    final guide = Path()
      ..moveTo(x(0.090), y(0.165))
      ..cubicTo(x(0.100), y(0.145), x(0.120), y(0.128), x(0.150), y(0.110))
      ..cubicTo(x(0.215), y(0.070), x(0.300), y(0.085), x(0.320), y(0.150))
      ..cubicTo(x(0.306), y(0.240), x(0.408), y(0.435), x(0.426), y(0.540))
      ..cubicTo(x(0.455), y(0.580), x(0.545), y(0.580), x(0.574), y(0.540))
      ..cubicTo(x(0.592), y(0.435), x(0.694), y(0.240), x(0.680), y(0.150))
      ..cubicTo(x(0.700), y(0.085), x(0.785), y(0.070), x(0.850), y(0.110))
      ..cubicTo(x(0.880), y(0.128), x(0.900), y(0.145), x(0.910), y(0.165));

    final List<PathMetric> metrics = guide.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final PathMetric metric = metrics.first;
    final double length = metric.length;
    if (length <= 0) return;

    final double stroke = side * 0.030;

    // Phase boundaries as fractions of the cycle, matching the old painter.
    final double menstrual = periodLength.toDouble();
    const double follicular = 9.0;
    const double ovulation = 2.0;
    const double expected = 3.0;
    final double p1 = menstrual / cycleLength;
    final double p2 = (menstrual + follicular) / cycleLength;
    final double p3 = (menstrual + follicular + ovulation) / cycleLength;
    double p4 = (cycleLength - expected) / cycleLength;
    if (p4 < p3) p4 = p3;

    final double travelled = length * progress.clamp(0.0, 1.0);

    void slice(double from, double to, Color color) {
      final double a = length * from;
      final double b = length * to;
      if (travelled <= a) return;
      final double end = travelled.clamp(a, b);
      if (end <= a) return;
      canvas.drawPath(
        metric.extractPath(a, end),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    slice(0.0, p1, _menstrual);
    slice(p1, p2, _follicular);
    slice(p2, p3, _ovulation);
    slice(p3, p4, _luteal);
    slice(p4, 1.0, _menstrual);

    // The travelling egg.
    final Tangent? tangent = metric.getTangentForOffset(travelled);
    final Offset egg = tangent?.position ?? Offset(x(0.090), y(0.165));

    Color eggColor = _menstrual;
    if (progress <= p1) {
      eggColor = _menstrual;
    } else if (progress <= p2) {
      eggColor = _follicular;
    } else if (progress <= p3) {
      eggColor = _ovulation;
    } else if (progress <= p4) {
      eggColor = _luteal;
    }

    final double r = side * 0.042;
    canvas.drawCircle(
      egg,
      r,
      Paint()
        ..color = const Color(0xFF2C2523).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.drawCircle(egg, r, Paint()..color = eggColor);
    canvas.drawCircle(egg, r * 0.66, Paint()..color = Colors.white);
    canvas.drawCircle(egg, r * 0.19, Paint()..color = eggColor);
  }

  @override
  bool shouldRepaint(covariant CycleAnatomyPainter old) {
    return old.progress != progress ||
        old.cycleLength != cycleLength ||
        old.periodLength != periodLength;
  }
}
