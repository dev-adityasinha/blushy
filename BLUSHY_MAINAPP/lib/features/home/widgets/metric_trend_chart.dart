import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colors.dart';

/// One reading on a trend line.
class MetricReading {
  const MetricReading({required this.day, required this.value});

  final DateTime day;
  final double value;
}

/// The recent history of a numeric metric.
///
/// A line rather than bars: what matters for basal temperature is the shape of
/// the change -- `detectBbtShift` looks for a sustained rise of 0.2 degrees --
/// and bars anchored at zero would flatten a range that only spans a degree.
/// The vertical scale is therefore the data's own range, not zero-based, and
/// the axis labels say so.
class MetricTrendChart extends StatelessWidget {
  const MetricTrendChart({
    super.key,
    required this.readings,
    required this.unit,
    required this.decimals,
    this.height = 130,
  });

  final List<MetricReading> readings;
  final String unit;
  final int decimals;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (readings.length < 2) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BlushyColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BlushyColors.border),
        ),
        child: Text(
          readings.isEmpty
              ? 'No readings yet.'
              : 'One reading so far. A trend needs a few days.',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: BlushyColors.secondaryText,
          ),
        ),
      );
    }

    final values = readings.map((r) => r.value).toList();
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: BlushyColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LAST ${readings.length}',
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: BlushyColors.secondaryText,
                ),
              ),
              Text(
                '${lowest.toStringAsFixed(decimals)}'
                ' – ${highest.toStringAsFixed(decimals)} $unit',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                readings: readings,
                lowest: lowest,
                highest: highest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.readings,
    required this.lowest,
    required this.highest,
  });

  final List<MetricReading> readings;
  final double lowest;
  final double highest;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || readings.length < 2) return;

    // A flat run has no range to divide by, so it is drawn down the middle
    // rather than dividing by zero or exaggerating noise into a peak.
    final double span = highest - lowest;
    const double pad = 10;
    final double usable = size.height - pad * 2;

    double yFor(double value) {
      if (span <= 0) return size.height / 2;
      return pad + (1 - (value - lowest) / span) * usable;
    }

    double xFor(int i) =>
        readings.length == 1 ? size.width / 2 : (i / (readings.length - 1)) * size.width;

    // A faint baseline at the lowest reading, so the line has something to sit
    // against without implying a zero the scale does not have.
    canvas.drawLine(
      Offset(0, size.height - pad),
      Offset(size.width, size.height - pad),
      Paint()
        ..color = BlushyColors.border
        ..strokeWidth = 1,
    );

    final path = Path();
    for (int i = 0; i < readings.length; i++) {
      final p = Offset(xFor(i), yFor(readings[i].value));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = BlushyColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (int i = 0; i < readings.length; i++) {
      final p = Offset(xFor(i), yFor(readings[i].value));
      final isLast = i == readings.length - 1;
      canvas.drawCircle(p, isLast ? 5 : 3, Paint()..color = BlushyColors.primary);
      if (isLast) {
        canvas.drawCircle(p, 2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.readings.length != readings.length ||
      old.lowest != lowest ||
      old.highest != highest ||
      old.readings.lastOrNull?.value != readings.lastOrNull?.value;
}
