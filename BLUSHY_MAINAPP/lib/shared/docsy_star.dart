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
  const DocsyStarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    // How far in the sides pull between the points. Smaller is sharper.
    final inner = r * 0.30;
    final path = Path()..moveTo(c.dx, c.dy - r);
    for (var i = 0; i < 4; i++) {
      final a0 = -math.pi / 2 + i * math.pi / 2;
      final a1 = a0 + math.pi / 2;
      final mid = a0 + math.pi / 4;
      final tip = Offset(c.dx + r * math.cos(a1), c.dy + r * math.sin(a1));
      final ctrl = Offset(c.dx + inner * math.cos(mid), c.dy + inner * math.sin(mid));
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant DocsyStarPainter old) => old.color != color;
}
