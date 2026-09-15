import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Docsy's mark: a four-point star with concave sides. The nav's Docsy
/// button carries it in white on red; anything else that stands for Docsy
/// -- the "Insights for your phase" row, say -- carries the same shape.
class DocsyStar extends StatelessWidget {
  const DocsyStar({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: DocsyStarPainter(color: color),
    );
  }
}

class DocsyStarPainter extends CustomPainter {
  const DocsyStarPainter({required this.color, this.strokeWidth});

  final Color color;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset c = Offset(w / 2, h / 2);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? math.max(1.5, w * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Draw elegant, smooth heart outline
    final path = Path();
    path.moveTo(c.dx, c.dy + h * 0.35);
    path.cubicTo(
      c.dx - w * 0.48, c.dy - h * 0.05,
      c.dx - w * 0.28, c.dy - h * 0.44,
      c.dx, c.dy - h * 0.12,
    );
    path.cubicTo(
      c.dx + w * 0.28, c.dy - h * 0.44,
      c.dx + w * 0.48, c.dy - h * 0.05,
      c.dx, c.dy + h * 0.35,
    );
    canvas.drawPath(path, strokePaint);

    // 2. Add luminous central AI spark dot inside heart
    canvas.drawCircle(Offset(c.dx, c.dy - h * 0.04), math.max(1.2, w * 0.11), fillPaint);
  }

  @override
  bool shouldRepaint(covariant DocsyStarPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
