import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════
// 1. THE EXACT BÉZIER PATH GENERATOR
// ════════════════════════════════════════════════════════════════
Path generateExactBlushyPath(Size size) {
  // Generous safety insets (padX: 14.0, padY: 10.0) so the 9.5px stroke and
  // the traveling egg indicator (with its 12.5px glow/shadow) are NEVER cropped.
  const double padX = 14.0;
  const double padY = 10.0;
  final double innerW = size.width - padX * 2;
  final double innerH = size.height - padY * 2;

  double px(double ratio) => padX + (innerW > 0 ? innerW * ratio : size.width * ratio);
  double py(double ratio) => padY + (innerH > 0 ? innerH * ratio : size.height * ratio);

  final path = Path();

  // 1. Start at bottom-left leg (cervical canal)
  path.moveTo(px(0.38), py(0.90));

  // 2. Left inner wall curve up
  path.cubicTo(
    px(0.37), py(0.76),
    px(0.31), py(0.54),
    px(0.28), py(0.44),
  );

  // 3. Left ovary / fimbriae loop
  path.cubicTo(
    px(0.25), py(0.34),
    px(0.18), py(0.30),
    px(0.18), py(0.42),
  );
  path.cubicTo(
    px(0.18), py(0.54),
    px(0.10), py(0.56),
    px(0.06), py(0.42),
  );
  path.cubicTo(
    px(0.02), py(0.26),
    px(0.08), py(0.14),
    px(0.14), py(0.14),
  );

  // 4. Top-left bridge sloping down to the center V-dip
  path.cubicTo(
    px(0.22), py(0.14),
    px(0.34), py(0.22),
    px(0.50), py(0.26), // Center V-dip (fundus)
  );

  // 5. Center V-dip rising up to the top-right bridge
  path.cubicTo(
    px(0.66), py(0.22),
    px(0.78), py(0.14),
    px(0.86), py(0.14),
  );

  // 6. Right ovary / fimbriae loop
  path.cubicTo(
    px(0.92), py(0.14),
    px(0.98), py(0.26),
    px(0.94), py(0.42),
  );
  path.cubicTo(
    px(0.90), py(0.56),
    px(0.82), py(0.54),
    px(0.82), py(0.42),
  );
  path.cubicTo(
    px(0.82), py(0.30),
    px(0.75), py(0.34),
    px(0.72), py(0.44),
  );

  // 7. Right inner wall curve down to bottom-right leg
  path.cubicTo(
    px(0.69), py(0.54),
    px(0.63), py(0.76),
    px(0.62), py(0.90),
  );

  return path;
}

// ════════════════════════════════════════════════════════════════
// 2. THE CUSTOM PAINTER (Segments + Traveling Egg)
// ════════════════════════════════════════════════════════════════
class ExactBlushyTrackPainter extends CustomPainter {
  final double progress;       // 0.0 to 1.0 (e.g. currentDay / cycleLength)
  final int cycleLength;        // Default 28
  final int periodLength;       // Default 5
  final bool showInactiveTrack; // Draw light neutral background or transparent
  final bool isLogged;          // If false, draw completely gray track without colored slices or egg

  ExactBlushyTrackPainter({
    required this.progress,
    this.cycleLength = 28,
    this.periodLength = 5,
    this.showInactiveTrack = true,
    this.isLogged = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Exact brand phase colors from the screenshot
    const Color colorMenstrual = Color(0xFFEF4444);  // Red
    const Color colorFollicular = Color(0xFFF97316); // Orange
    const Color colorOvulation = Color(0xFFFACC15);  // Yellow
    const Color colorLuteal = Color(0xFF7C3AED);     // Purple
    const Color colorInactive = Color(0xFFECEAE7);   // Soft Gray

    final Path path = generateExactBlushyPath(size);
    final List<ui.PathMetric> metricsList = path.computeMetrics().toList();
    if (metricsList.isEmpty) return;

    final ui.PathMetric metric = metricsList.first;
    final double pathLength = metric.length;
    if (pathLength <= 0) return;

    // 1. Draw base neutral track
    canvas.drawPath(
      path,
      Paint()
        ..color = colorInactive
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // If period is not logged, keep tracker COMPLETELY GRAY with no slices and no egg
    if (!isLogged) return;

    // 2. Calculate phase thresholds
    final double p1 = (periodLength / cycleLength).clamp(0.0, 1.0);
    final double p2 = ((periodLength + 9.0) / cycleLength).clamp(0.0, 1.0);
    final double p3 = ((periodLength + 11.0) / cycleLength).clamp(0.0, 1.0);

    final double activeOffset = pathLength * progress.clamp(0.0, 1.0);

    // Slice drawer helper
    void drawSlice(double startP, double endP, Color color) {
      final double startO = pathLength * startP;
      final double endO = pathLength * endP;
      if (activeOffset > startO) {
        final double limitO = activeOffset.clamp(startO, endO);
        if (limitO > startO) {
          final Path slice = metric.extractPath(startO, limitO);
          canvas.drawPath(
            slice,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9.5
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // 3. Draw color segments sequentially along the path
    drawSlice(0.0, p1, colorMenstrual);
    drawSlice(p1, p2, colorFollicular);
    drawSlice(p2, p3, colorOvulation);
    drawSlice(p3, 1.0, colorLuteal);

    // 4. Draw Traveling Egg Indicator (matches bottom-right of screenshot)
    final tangent = metric.getTangentForOffset(activeOffset);
    final eggPos = tangent?.position ?? Offset(size.width * 0.38, size.height * 0.90);

    Color activeColor = colorMenstrual;
    if (progress > p3) {
      activeColor = colorLuteal;
    } else if (progress > p2) {
      activeColor = colorOvulation;
    } else if (progress > p1) {
      activeColor = colorFollicular;
    }

    // Subtle drop shadow
    canvas.drawCircle(
      eggPos,
      10.0,
      Paint()
        ..color = const Color(0xFF221510).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Outer phase-colored ring
    canvas.drawCircle(
      eggPos,
      9.5,
      Paint()..color = activeColor..style = PaintingStyle.fill,
    );

    // White body
    canvas.drawCircle(
      eggPos,
      6.5,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );

    // Center nucleus dot
    canvas.drawCircle(
      eggPos,
      2.5,
      Paint()..color = activeColor..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant ExactBlushyTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cycleLength != cycleLength ||
        oldDelegate.periodLength != periodLength ||
        oldDelegate.isLogged != isLogged;
  }
}

// ════════════════════════════════════════════════════════════════
// 3. READY-TO-USE WIDGET (With Logging and Tap Integration)
// ════════════════════════════════════════════════════════════════
class ExactBlushyTrackerWidget extends StatelessWidget {
  final int currentDay;
  final int cycleLength;
  final int periodLength;
  final bool isLogged;
  /// What tapping the tracker does.
  ///
  /// It was `onTapLog`, and every caller opened the date picker -- so tapping
  /// a drawing of where she is in her cycle asked her to log a period she had
  /// already logged. The name is neutral now because what a tap should do
  /// depends on whether there is a cycle to explain, and that is the caller's
  /// decision rather than this widget's.
  final VoidCallback? onTap;

  const ExactBlushyTrackerWidget({
    super.key,
    this.currentDay = 1,
    this.cycleLength = 28,
    this.periodLength = 5,
    this.isLogged = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const canvasSize = Size(280, 130);

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: CustomPaint(
              size: canvasSize,
              painter: ExactBlushyTrackPainter(
                progress: isLogged ? (currentDay / cycleLength).clamp(0.0, 1.0) : 0.0,
                cycleLength: cycleLength,
                periodLength: periodLength,
                isLogged: isLogged,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility wrapper for CycleTrackerImage
class CycleTrackerImage extends StatelessWidget {
  const CycleTrackerImage({
    super.key,
    required this.progress,
    this.activePhase = 'Menstrual',
    this.cycleLength = 28,
    this.periodLength = 5,
    this.isLogged = true,
  });

  final double progress;
  final String activePhase;
  final int cycleLength;
  final int periodLength;
  final bool isLogged;

  @override
  Widget build(BuildContext context) {
    const canvasSize = Size(280, 130);
    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: CustomPaint(
        size: canvasSize,
        painter: ExactBlushyTrackPainter(
          progress: progress,
          cycleLength: cycleLength,
          periodLength: periodLength,
          isLogged: isLogged,
        ),
      ),
    );
  }
}

typedef FallopianTrackPainter = ExactBlushyTrackPainter;
