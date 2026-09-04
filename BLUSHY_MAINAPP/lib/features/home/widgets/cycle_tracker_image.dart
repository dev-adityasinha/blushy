import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import 'cycle_tracker_guide.dart';

/// The tracker: the supplied drawing, with the cycle traced along it.
///
/// `assets/ptracker.png` is the drawing with its red and its ring removed
/// (tool/prepare_ptracker.py). This lays the red back along the line from
/// the drawing's start up to today, and puts the ring on today. The line's
/// centre comes from [cycleTrackerGuide], traced from the same drawing, so
/// the red sits on the grey at every point.
///
/// The animation is not here. [progress] is whatever the cycle card's
/// controller is at -- settling to today on open, and the tap-to-sweep --
/// and both drive this through the one number.
class CycleTrackerImage extends StatelessWidget {
  const CycleTrackerImage({super.key, required this.progress});

  /// How far through the cycle, 0..1.
  final double progress;

  static const String asset = 'assets/ptracker.png';

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: cycleTrackerAspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.fill, filterQuality: FilterQuality.high),
          IgnorePointer(
            child: CustomPaint(painter: _ProgressPainter(progress: progress)),
          ),
        ],
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || cycleTrackerGuide.length < 2) return;
    final pts = [
      for (final p in cycleTrackerGuide) Offset(p.dx * size.width, p.dy * size.height),
    ];
    // The stroke matches the drawing's line, which is about 2.6% of its
    // width, so the red covers the grey rather than sitting on it.
    final stroke = size.width * 0.026;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final metric = path.computeMetrics().first;
    final at = metric.length * progress.clamp(0.0, 1.0);

    if (at > 0) {
      canvas.drawPath(
        metric.extractPath(0, at),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = BlushyColors.primary,
      );
    }

    // Today: a ring, white inside, with a dot at its centre.
    final tangent = metric.getTangentForOffset(at);
    if (tangent == null) return;
    final c = tangent.position;
    final r = stroke * 1.7;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.6
        ..color = BlushyColors.primary,
    );
    canvas.drawCircle(c, stroke * 0.35, Paint()..color = BlushyColors.primary);
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter old) => old.progress != progress;
}
