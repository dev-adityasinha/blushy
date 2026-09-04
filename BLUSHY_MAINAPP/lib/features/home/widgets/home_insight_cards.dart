import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/blushy_surface.dart';
import '../../../shared/section_heading.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';

/// The two insight sections while there is nothing to show yet, and the
/// privacy line under them.
///
/// These are the empty states. The message in each comes from the API layer
/// -- "once you have logged a few days", "keep logging for a couple of weeks"
/// -- and is passed in, so what the card says still tracks what the server
/// actually said about the data. Nothing here decides whether there is enough
/// of it.

/// Docsy Insights, before Docsy has anything to say.
class DocsyInsightsCard extends StatelessWidget {
  const DocsyInsightsCard({
    super.key,
    required this.heading,
    required this.note,
    required this.actionLabel,
    required this.onAction,
  });

  /// The section eyebrow, already localised.
  final String heading;

  /// Why there is nothing yet, from the API state.
  final String note;

  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(heading),
          const SizedBox(height: BlushySpace.xs + 2),
          Text(
            note,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7A6B72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: BlushySpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _ActionButton(label: actionLabel, onTap: onAction, filled: false),
          ),
        ],
      ),
    );
  }
}

/// Cycle Patterns, before there are enough logs to find any.
class PatternsEmptyCard extends StatelessWidget {
  const PatternsEmptyCard({
    super.key,
    required this.heading,
    required this.note,
    required this.actionLabel,
    required this.onAction,
    required this.onRefresh,
  });

  final String heading;

  /// Why there is nothing yet, from the API state.
  final String note;

  final String actionLabel;
  final VoidCallback onAction;

  /// Recomputes from current logs. Kept from the old header: it does not
  /// create a duplicate insight.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionHeading(heading)),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                color: BlushyColors.primary,
                tooltip: 'Recalculate',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: BlushySpace.xs),
          Text(
            note,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7A6B72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: BlushySpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _ActionButton(label: actionLabel, onTap: onAction, filled: false),
          ),
        ],
      ),
    );
  }
}

/// The line under the insights saying who can see them.
class PrivacyRow extends StatelessWidget {
  const PrivacyRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9F6F2),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(BlushySpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAE3DC), width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: BlushySpace.tile,
                height: BlushySpace.tile,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 18, color: BlushyColors.primary),
              ),
              const SizedBox(width: BlushySpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your data is private and secure.',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: BlushyColors.text,
                      ),
                    ),
                    Text(
                      'Only you can see your insights.',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: const Color(0xFF7A6B72),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFB5A9AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BlushySpace.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAE3DC), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: BlushyColors.primary),
          const SizedBox(width: BlushySpace.md),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: BlushyColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's one action: filled where it is the page's main ask, outlined
/// where the same ask is being made a second time further down.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : BlushyColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: filled ? BlushyColors.primary : Colors.white,
            border: filled
                ? null
                : Border.all(color: const Color(0xFFF7D8DD), width: 0.8),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Docsy, holding a tablet, with three of the things it reads in orbit.
///
/// Drawn rather than shipped as an image: there is no image of Docsy in the
/// project, and a drawing takes the brand colour and scales to any card.
class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(child: CustomPaint(painter: _MascotPainter())),
        for (final (dx, dy, icon, color) in const [
          (0.0, -0.92, Icons.calendar_month_rounded, BlushyColors.primary),
          (-0.95, -0.35, Icons.local_florist_rounded, BlushyColors.secondary),
          (0.95, -0.35, Icons.sentiment_satisfied_rounded, BlushyColors.secondary),
        ])
          Align(
            alignment: Alignment(dx, dy),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: BlushySurface.shadow,
              ),
              child: Icon(icon, size: 17, color: color),
            ),
          ),
      ],
    );
  }
}

class _MascotPainter extends CustomPainter {
  const _MascotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // The pale disc everything sits on.
    canvas.drawCircle(
      Offset(cx, h * 0.58),
      math.min(w, h) * 0.42,
      Paint()..color = BlushyColors.primary.withValues(alpha: 0.07),
    );

    // The dashed orbit the three satellites sit on.
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = BlushyColors.primary.withValues(alpha: 0.25);
    final centre = Offset(cx, h * 0.46);
    final radius = math.min(w, h) * 0.44;
    const dash = 0.08;
    for (var a = math.pi; a < math.pi * 2; a += dash * 2) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        a,
        dash,
        false,
        orbit,
      );
    }

    // The body: a soft ball, lighter at the top.
    final body = Offset(cx, h * 0.66);
    final bodyR = math.min(w, h) * 0.26;
    canvas.drawCircle(
      body,
      bodyR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: [Colors.white, Color.lerp(Colors.white, BlushyColors.secondary, 0.45)!],
        ).createShader(Rect.fromCircle(center: body, radius: bodyR)),
    );

    // Closed happy eyes: two small arcs.
    final eye = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = BlushyColors.text;
    for (final side in [-1, 1]) {
      final e = Offset(body.dx + side * bodyR * 0.38, body.dy - bodyR * 0.12);
      canvas.drawArc(
        Rect.fromCircle(center: e, radius: bodyR * 0.16),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        eye,
      );
    }

    // Cheeks and a smile.
    final cheek = Paint()..color = BlushyColors.secondary.withValues(alpha: 0.6);
    for (final side in [-1, 1]) {
      canvas.drawCircle(
        Offset(body.dx + side * bodyR * 0.55, body.dy + bodyR * 0.12),
        bodyR * 0.12,
        cheek,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(body.dx, body.dy + bodyR * 0.08),
        radius: bodyR * 0.18,
      ),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      eye,
    );

    // The tablet it is holding, tipped forward.
    final tablet = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(body.dx, body.dy + bodyR * 0.72),
        width: bodyR * 1.15,
        height: bodyR * 0.8,
      ),
      Radius.circular(bodyR * 0.14),
    );
    canvas.drawRRect(
      tablet,
      Paint()
        ..shader = const LinearGradient(
          colors: [BlushyColors.secondary, BlushyColors.primary],
        ).createShader(tablet.outerRect),
    );
    // Two small hands on its edge.
    final hand = Paint()..color = Color.lerp(Colors.white, BlushyColors.secondary, 0.45)!;
    for (final side in [-1, 1]) {
      canvas.drawCircle(
        Offset(body.dx + side * bodyR * 0.6, body.dy + bodyR * 0.55),
        bodyR * 0.14,
        hand,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) => false;
}

/// A tilted chart card with a calendar leaning on it.
///
/// Decorative: the line on it is a shape, not a reading, and it carries no
/// number. A figure here would be one nobody logged.
class _ChartIllustration extends StatelessWidget {
  const _ChartIllustration();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _ChartPainter());
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;

    // A soft glow behind the card.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      math.min(w, h) * 0.46,
      Paint()..color = BlushyColors.primary.withValues(alpha: 0.06),
    );

    // The card, leaning back a little.
    canvas.save();
    canvas.translate(w * 0.46, h * 0.46);
    canvas.rotate(-0.06);
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.78, height: h * 0.7),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      card.shift(const Offset(0, 4)),
      Paint()
        ..color = BlushyColors.text.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);

    // A label bar where a title would go.
    final left = card.left + 10;
    final top = card.top + 10;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w * 0.3, 6),
        const Radius.circular(3),
      ),
      Paint()..color = BlushyColors.primary.withValues(alpha: 0.18),
    );

    // The line: a shape, not data.
    final points = <Offset>[
      Offset(left, card.bottom - 18),
      Offset(left + w * 0.14, card.bottom - 34),
      Offset(left + w * 0.28, card.bottom - 24),
      Offset(left + w * 0.42, card.bottom - 46),
      Offset(left + w * 0.56, card.bottom - 30),
      Offset(left + w * 0.66, card.bottom - 40),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = BlushyColors.primary,
    );
    for (final p in points) {
      canvas.drawCircle(p, 2.6, Paint()..color = BlushyColors.primary);
    }
    canvas.restore();

    // The calendar leaning against it, bottom right.
    final cal = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.6, h * 0.58, w * 0.3, h * 0.32),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      cal.shift(const Offset(0, 3)),
      Paint()
        ..color = BlushyColors.text.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(cal, Paint()..color = Color.lerp(BlushyColors.background, BlushyColors.secondary, 0.30)!);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cal.left, cal.top, cal.width, cal.height * 0.28),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      Paint()..color = BlushyColors.secondary,
    );
    // Rings along the top edge.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = BlushyColors.text.withValues(alpha: 0.45);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(cal.left + cal.width * (0.2 + i * 0.2), cal.top),
        2.2,
        ring,
      );
    }
    // A heart on the page.
    final heart = Path();
    final hc = Offset(cal.left + cal.width / 2, cal.top + cal.height * 0.64);
    final hs = cal.width * 0.16;
    heart
      ..moveTo(hc.dx, hc.dy + hs * 0.9)
      ..cubicTo(hc.dx - hs * 1.6, hc.dy - hs * 0.3, hc.dx - hs * 0.6,
          hc.dy - hs * 1.3, hc.dx, hc.dy - hs * 0.4)
      ..cubicTo(hc.dx + hs * 0.6, hc.dy - hs * 1.3, hc.dx + hs * 1.6,
          hc.dy - hs * 0.3, hc.dx, hc.dy + hs * 0.9)
      ..close();
    canvas.drawPath(heart, Paint()..color = BlushyColors.primary);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => false;
}
