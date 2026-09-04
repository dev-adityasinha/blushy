import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'note_style.dart';

/// The page a note is written on.
///
/// Two jobs in one painter. For the ruled papers it draws lines or dots in the
/// note's own ink, so the dark paper gets light ruling rather than a fixed grey
/// that would disappear on it. For the decorated ones it draws the whole page:
/// a printed ground, and a panel of paper laid on top that the writing sits in.
///
/// Drawn rather than shipped as images. The references are other people's
/// artwork, and a drawn page also scales to any screen and adds nothing to the
/// bundle.
class NotePaper extends CustomPainter {
  NotePaper({
    required this.template,
    required this.ink,
    required this.panel,
    this.lineHeight = 28,
    this.hasPhotoBehind = false,
  });

  final NoteTemplate template;
  final Color ink;

  /// The colour of the sheet that is written on. For a decorated page this is
  /// the panel; for a ruled one it is the whole page, already painted behind.
  final Color panel;

  final double lineHeight;

  /// Whether a photograph is already drawn behind this painter.
  final bool hasPhotoBehind;

  /// Where the writing goes, for a given page size.
  ///
  /// Shared with the editor so the text sits inside the panel rather than over
  /// the decoration. A single source for it, because a mismatch here writes
  /// words across the border and looks broken rather than styled.
  static Rect panelRect(NoteTemplate template, Size size) {
    if (!template.isDecorated) return Offset.zero & size;
    final shortest = math.min(size.width, size.height);
    final margin = shortest * template.inset;
    return Rect.fromLTRB(
      shortest * (template.insetLeft ?? template.inset),
      margin,
      size.width - margin,
      size.height - margin,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (template.isDecorated) {
      _paintDecorated(canvas, size);
      return;
    }
    _paintRuling(canvas, Offset.zero & size);
  }

  // --- ruled papers ---------------------------------------------------------

  void _paintRuling(Canvas canvas, Rect area) {
    if (template == NoteTemplate.plain || lineHeight <= 0) return;

    final paint = Paint()
      ..color = ink.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    switch (template) {
      case NoteTemplate.lined:
        for (double y = area.top + lineHeight; y < area.bottom; y += lineHeight) {
          canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
        }
      case NoteTemplate.grid:
        for (double y = area.top + lineHeight; y < area.bottom; y += lineHeight) {
          canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
        }
        for (double x = area.left + lineHeight; x < area.right; x += lineHeight) {
          canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), paint);
        }
      case NoteTemplate.dotted:
        final dot = Paint()..color = ink.withValues(alpha: 0.25);
        for (double y = area.top + lineHeight; y < area.bottom; y += lineHeight) {
          for (double x = area.left + lineHeight; x < area.right; x += lineHeight) {
            canvas.drawCircle(Offset(x, y), 1.1, dot);
          }
        }
      default:
        return;
    }
  }

  // --- decorated pages ------------------------------------------------------

  void _paintDecorated(Canvas canvas, Size size) {
    final ground = Color(template.ground!);
    final accent = Color(template.accent!);
    final rect = panelRect(template, size);

    // Skipped when a photo is showing behind: painting the fallback over it
    // would hide the very thing that was chosen.
    if (!hasPhotoBehind) {
      canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    }

    switch (template) {
      case NoteTemplate.wavyFrame:
        _stripes(canvas, size, accent.withValues(alpha: 0.55));
        _wavyPanel(canvas, rect, accent);
      case NoteTemplate.gingham:
        _gingham(canvas, size, const Color(0xFFFFFFFF));
        _tornPanel(canvas, rect, seed: 7);
      case NoteTemplate.tornPaper:
        _tornPanel(canvas, rect, seed: 3);
      case NoteTemplate.pressedFlowers:
        _tornPanel(canvas, rect, seed: 11);
        // Over the panel edge, the way a pressed flower actually sits.
        _flower(canvas, Offset(rect.left + rect.width * 0.10, rect.top), accent,
            math.min(size.width, size.height) * 0.22);
        _flower(
            canvas,
            Offset(rect.right - rect.width * 0.12, rect.bottom),
            accent,
            math.min(size.width, size.height) * 0.24);
      case NoteTemplate.ribbon:
        _graphGround(canvas, size, const Color(0xFFE4A0A8));
        _softPanel(canvas, rect);
        // Over the panel, not under it: underneath, the sheet covered all but
        // the corners and the page read as plain graph paper.
        _ribbon(canvas, size, accent);
      case NoteTemplate.photo:
        // The ground here was already painted by the widget behind, when a
        // photo is set. Only the sheet belongs to the painter.
        _tornPanel(canvas, rect, seed: 5);
      case NoteTemplate.botanical:
        _softPanel(canvas, rect);
        _botanical(canvas, size, accent);
      default:
        _softPanel(canvas, rect);
    }
  }

  /// Vertical bands, as on a striped wrapper.
  void _stripes(Canvas canvas, Size size, Color colour) {
    final paint = Paint()..color = colour;
    final width = size.width / 11;
    for (double x = 0; x < size.width; x += width * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
    }
  }

  /// A checked cloth: two passes of translucent bands, so the overlaps darken
  /// on their own rather than needing a third colour.
  void _gingham(Canvas canvas, Size size, Color colour) {
    final cell = math.min(size.width, size.height) / 9;
    final paint = Paint()..color = colour.withValues(alpha: 0.55);
    for (double x = 0; x < size.width; x += cell * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, cell, size.height), paint);
    }
    for (double y = 0; y < size.height; y += cell * 2) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, cell), paint);
    }
  }

  /// Fine graph ruling across the whole page, behind everything.
  void _graphGround(Canvas canvas, Size size, Color colour) {
    final cell = math.min(size.width, size.height) / 22;
    final paint = Paint()
      ..color = colour.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    for (double y = 0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  /// A plain sheet with a soft shadow, as if laid on the ground.
  void _softPanel(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, 3), const Radius.circular(4)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = panel,
    );
    _paintRuling(canvas, rect.deflate(12));
  }

  /// A panel inside a wavy border.
  void _wavyPanel(Canvas canvas, Rect rect, Color border) {
    final path = _wavyRect(rect, amplitude: rect.shortestSide * 0.028);

    canvas.drawPath(path, Paint()..color = panel);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.shortestSide * 0.035,
    );
    _paintRuling(canvas, rect.deflate(rect.shortestSide * 0.12));
  }

  /// A rectangle whose sides ripple.
  ///
  /// The wavelength is constant rather than a fixed number of waves per edge:
  /// with a fixed count the short sides get the same seven cycles as the long
  /// ones, which reads as a zigzag rather than a ripple. Sampled densely for
  /// the same reason -- too few points per cycle and the curve turns to spikes.
  Path _wavyRect(Rect rect, {required double amplitude}) {
    final wavelength = rect.shortestSide * 0.28;
    final perimeter = <Offset>[];

    void edge(Offset from, Offset to, Offset normal) {
      final length = (to - from).distance;
      final cycles = math.max(1, (length / wavelength).round());
      final steps = math.max(24, cycles * 18);
      for (int i = 0; i < steps; i++) {
        final t = i / steps;
        final base = Offset.lerp(from, to, t)!;
        // Full cycles per edge, so the corners meet at the same phase and the
        // ripple runs continuously round the frame.
        final wave = math.sin(t * cycles * math.pi * 2) * amplitude;
        perimeter.add(base + normal * wave);
      }
    }

    edge(rect.topLeft, rect.topRight, const Offset(0, -1));
    edge(rect.topRight, rect.bottomRight, const Offset(1, 0));
    edge(rect.bottomRight, rect.bottomLeft, const Offset(0, 1));
    edge(rect.bottomLeft, rect.topLeft, const Offset(-1, 0));

    return Path()..addPolygon(perimeter, true);
  }

  /// A sheet with a deckled edge, as if torn by hand.
  void _tornPanel(Canvas canvas, Rect rect, {required int seed}) {
    final random = math.Random(seed);
    final rough = rect.shortestSide * 0.018;
    final path = Path();
    final points = <Offset>[];

    void edge(Offset from, Offset to) {
      const steps = 26;
      for (int i = 0; i < steps; i++) {
        final t = i / steps;
        final base = Offset.lerp(from, to, t)!;
        points.add(base +
            Offset(
              (random.nextDouble() - 0.5) * rough * 2,
              (random.nextDouble() - 0.5) * rough * 2,
            ));
      }
    }

    edge(rect.topLeft, rect.topRight);
    edge(rect.topRight, rect.bottomRight);
    edge(rect.bottomRight, rect.bottomLeft);
    edge(rect.bottomLeft, rect.topLeft);
    path.addPolygon(points, true);

    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(path, Paint()..color = panel);
    _paintRuling(canvas, rect.deflate(rect.shortestSide * 0.09));
  }

  /// A simple flower: petals round a centre. Not botanical accuracy, and not
  /// trying to be -- a drawn approximation reads as decoration, whereas a bad
  /// realistic one reads as a mistake.
  void _flower(Canvas canvas, Offset centre, Color colour, double radius) {
    final petal = Paint()..color = colour.withValues(alpha: 0.85);
    const petals = 7;
    for (int i = 0; i < petals; i++) {
      final angle = (i / petals) * math.pi * 2;
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * radius * 0.52;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: radius * 0.78, height: radius * 0.42),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      centre,
      radius * 0.22,
      Paint()..color = const Color(0xFFF3E2A9),
    );
  }

  /// A ribbon curving across the page, behind the panel.
  void _ribbon(Canvas canvas, Size size, Color colour) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.14)
      ..cubicTo(size.width * 0.45, size.height * 0.02, size.width * 0.62,
          size.height * 0.28, size.width * 0.92, size.height * 0.12)
      ..moveTo(size.width * 0.10, size.height * 0.90)
      ..cubicTo(size.width * 0.40, size.height * 1.02, size.width * 0.66,
          size.height * 0.78, size.width * 0.94, size.height * 0.92);

    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.min(size.width, size.height) * 0.018
        ..strokeCap = StrokeCap.round,
    );
  }

  /// A stem of flowers up the left of the page.
  void _botanical(Canvas canvas, Size size, Color colour) {
    final stem = Paint()
      ..color = const Color(0xFF6E8B5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(size.width, size.height) * 0.012
      ..strokeCap = StrokeCap.round;

    // Anchored in the left margin the wider inset leaves.
    final base = Offset(size.width * 0.13, size.height * 0.98);
    for (int i = 0; i < 3; i++) {
      final lean = (i - 1) * 0.045;
      final top = Offset(
        size.width * (0.13 + lean),
        size.height * (0.20 + i * 0.13),
      );
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            size.width * (0.07 + lean),
            size.height * 0.62,
            top.dx,
            top.dy,
          ),
        stem,
      );
      _flower(canvas, top, colour, math.min(size.width, size.height) * 0.15);
    }
  }

  @override
  bool shouldRepaint(covariant NotePaper old) =>
      old.template != template ||
      old.ink != ink ||
      old.panel != panel ||
      old.lineHeight != lineHeight ||
      old.hasPhotoBehind != hasPhotoBehind;
}
