import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/api_insights_service.dart';
import '../../../shared/blushy_surface.dart';
import '../../../shared/section_heading.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';

/// The last completed month, as a journey.
///
/// A rail down the left with a marker per milestone -- filled green where it
/// was reached, an empty ring where it was not -- each with a tile, a title
/// and a line of description; then Docsy's reflection on the month in a
/// quote panel. The milestones and the reflection are the server's (or the
/// local fallback's while offline); this only lays them out.
class MonthlyJourneyCard extends StatelessWidget {
  const MonthlyJourneyCard({
    super.key,
    required this.heading,
    required this.monthLabel,
    required this.milestones,
    required this.reflectionHeading,
    required this.reflection,
  });

  /// The section eyebrow.
  final String heading;

  /// Which month this reports, worded -- "July 2026" -- or null where the
  /// month is not known.
  final String? monthLabel;

  final List<MilestoneItem> milestones;

  /// The eyebrow over the quote, already localised.
  final String reflectionHeading;

  /// Docsy's line on the month.
  final String reflection;

  /// The mark for each milestone, by its id. Anything unrecognised gets a
  /// sparkle rather than nothing, so a new milestone from the server still
  /// has a tile.
  static IconData iconFor(String id) {
    switch (id) {
      case 'milestone_checkin_consistency':
        return Icons.calendar_month_rounded;
      case 'milestone_symptom_tracking':
        return Icons.assignment_rounded;
      case 'milestone_cycle_logging':
        return Icons.event_available_rounded;
      case 'milestone_sia_engagement':
        return Icons.chat_bubble_rounded;
    }
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    return BlushySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(heading, icon: Icons.auto_awesome),
          if (monthLabel != null) ...[
            const SizedBox(height: BlushySpace.xs),
            Text(monthLabel!, style: BlushyType.caption()),
          ],
          const SizedBox(height: BlushySpace.lg),
          for (var i = 0; i < milestones.length; i++)
            _MilestoneRow(
              milestone: milestones[i],
              isFirst: i == 0,
              isLast: i == milestones.length - 1,
            ),
          const SizedBox(height: BlushySpace.lg),
          _ReflectionPanel(heading: reflectionHeading, text: reflection),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.isFirst,
    required this.isLast,
  });

  final MilestoneItem milestone;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = milestone.showGreenTick;
    final tint = done ? BlushyColors.success : BlushyColors.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rail: a marker, and a dashed line to the next one.
          SizedBox(
            width: 28,
            child: CustomPaint(
              painter: _RailPainter(
                done: done,
                drawAbove: !isFirst,
                drawBelow: !isLast,
              ),
            ),
          ),
          const SizedBox(width: BlushySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: BlushySpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: BlushySpace.tile,
                        height: BlushySpace.tile,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          MonthlyJourneyCard.iconFor(milestone.id),
                          size: BlushySpace.iconTile,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: BlushySpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(milestone.title, style: BlushyType.heading()),
                            const SizedBox(height: 2),
                            Text(milestone.description,
                                style: BlushyType.body()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, thickness: 1, color: BlushyColors.border),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The marker and the dashed connector for one row of the rail.
class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.done,
    required this.drawAbove,
    required this.drawBelow,
  });

  final bool done;
  final bool drawAbove;
  final bool drawBelow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // The marker sits level with the row's tile, which starts md from the
    // top and is 44 tall.
    final cy = BlushySpace.md + 22;
    const r = 11.0;

    final dash = Paint()
      ..color = BlushyColors.border
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    void dashed(double from, double to) {
      for (var y = from; y < to; y += 7) {
        canvas.drawLine(Offset(cx, y), Offset(cx, math.min(y + 3.5, to)), dash);
      }
    }

    if (drawAbove) dashed(0, cy - r - 4);
    if (drawBelow) dashed(cy + r + 4, size.height);

    if (done) {
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = BlushyColors.success);
      // A tick, drawn rather than an icon so it is centred on the disc.
      final tick = Path()
        ..moveTo(cx - 4.5, cy + 0.5)
        ..lineTo(cx - 1.2, cy + 3.8)
        ..lineTo(cx + 5, cy - 3.5);
      canvas.drawPath(
        tick,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    } else {
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = BlushyColors.primary.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      old.done != done || old.drawAbove != drawAbove || old.drawBelow != drawBelow;
}

/// Docsy's line on the month, set as a quotation.
class _ReflectionPanel extends StatelessWidget {
  const _ReflectionPanel({required this.heading, required this.text});

  final String heading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BlushySpace.lg),
      decoration: BoxDecoration(
        color: BlushyColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      // The heading runs the full width of the panel, above the quote and
      // the picture. Sharing the quote's column left it ~60% of the panel,
      // where "DOCSY'S REFLECTION" came out as "DOCSY'S REFLECTI...".
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 26, color: BlushyColors.primary.withValues(alpha: 0.45)),
              const SizedBox(width: BlushySpace.sm),
              Expanded(
                child: Text(
                  heading,
                  style: BlushyType.micro(
                    color: BlushyColors.primary,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BlushySpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '"$text"',
                  style: BlushyType.heading(
                    color: BlushyColors.text,
                    weight: FontWeight.w600,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(width: BlushySpace.md),
              const Expanded(
                flex: 2,
                child: SizedBox(
                    height: 110, child: CustomPaint(painter: _JournalPainter())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A closed journal with a heart on the cover, a pen beside it, a leaf
/// behind. Drawn, because there is no image of it in the project.
class _JournalPainter extends CustomPainter {
  const _JournalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;

    // The leaf, tucked behind the book's top-left corner.
    final leaf = Paint()..color = BlushyColors.success;
    for (final (dx, dy, rot) in const [(0.22, 0.32, -0.9), (0.14, 0.44, -0.5)]) {
      canvas.save();
      canvas.translate(w * dx, h * dy);
      canvas.rotate(rot);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.22, height: w * 0.1), leaf);
      canvas.restore();
    }

    // The book, tipped a little.
    canvas.save();
    canvas.translate(w * 0.52, h * 0.55);
    canvas.rotate(-0.12);
    final book = Rect.fromCenter(center: Offset.zero, width: w * 0.5, height: h * 0.62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(book.shift(const Offset(0, 4)), const Radius.circular(6)),
      Paint()
        ..color = BlushyColors.text.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Pages, showing along the right edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(book.shift(const Offset(4, 2)), const Radius.circular(6)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(book, const Radius.circular(6)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BlushyColors.secondary, BlushyColors.primary],
        ).createShader(book),
    );
    // The spine.
    canvas.drawRect(
      Rect.fromLTWH(book.left, book.top, book.width * 0.12, book.height),
      Paint()..color = Color.lerp(BlushyColors.primary, BlushyColors.text, 0.15)!,
    );
    // A heart on the cover.
    final hc = Offset(book.center.dx + book.width * 0.06, book.center.dy);
    final hs = book.width * 0.16;
    final heart = Path()
      ..moveTo(hc.dx, hc.dy + hs * 0.9)
      ..cubicTo(hc.dx - hs * 1.6, hc.dy - hs * 0.3, hc.dx - hs * 0.6, hc.dy - hs * 1.3, hc.dx, hc.dy - hs * 0.4)
      ..cubicTo(hc.dx + hs * 0.6, hc.dy - hs * 1.3, hc.dx + hs * 1.6, hc.dy - hs * 0.3, hc.dx, hc.dy + hs * 0.9)
      ..close();
    canvas.drawPath(heart, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.restore();

    // The pen, leaning on the book's right side.
    canvas.save();
    canvas.translate(w * 0.84, h * 0.6);
    canvas.rotate(0.55);
    final pen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.07, height: h * 0.62),
      const Radius.circular(3),
    );
    canvas.drawRRect(pen, Paint()..color = BlushyColors.lutealAccent);
    final nib = Path()
      ..moveTo(-w * 0.035, h * 0.31)
      ..lineTo(w * 0.035, h * 0.31)
      ..lineTo(0, h * 0.40)
      ..close();
    canvas.drawPath(nib, Paint()..color = BlushyColors.clay);
    canvas.restore();

    // A sparkle or two.
    final sparkle = Paint()..color = BlushyColors.primary.withValues(alpha: 0.35);
    for (final (dx, dy, r) in const [(0.9, 0.18, 4.0), (0.3, 0.8, 3.0)]) {
      final c = Offset(w * dx, h * dy);
      canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), sparkle..strokeWidth = 1.5);
      canvas.drawLine(c - Offset(0, r), c + Offset(0, r), sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _JournalPainter old) => false;
}
