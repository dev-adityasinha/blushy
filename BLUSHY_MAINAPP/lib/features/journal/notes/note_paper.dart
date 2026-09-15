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

      // Written-on papers: ruling straight on the ground, no sheet over it.
      case NoteTemplate.notebookMint:
        _handRules(canvas, size, accent, seed: 2);
        _marginRule(canvas, size, const Color(0xFFEFA6B6));
      case NoteTemplate.notebookBlue:
        _handRules(canvas, size, accent, seed: 5);
      case NoteTemplate.gridOat:
        _squares(canvas, size, accent);
      case NoteTemplate.gridRed:
        _squares(canvas, size, accent);

      // Drawn-on pages: a ground with something on it, and the writing goes
      // in the clear middle.
      case NoteTemplate.squiggleGrid:
        _squares(canvas, size, const Color(0xFFCFC4B6));
        _squiggleBorder(canvas, size, accent, const Color(0xFFE9A0A8));
      case NoteTemplate.heartsGrid:
        _squares(canvas, size, const Color(0xFFD8D8D8));
        _ribbonHearts(canvas, size, accent, const Color(0xFFD62828));
      case NoteTemplate.wavyGold:
        _squares(canvas, size, const Color(0xFFCFC4B6));
        _goldWaveFrame(canvas, size, accent, const Color(0xFFF0509A));
      case NoteTemplate.rainbowPage:
        _rainbowWash(canvas, size);
        _handRules(canvas, size, accent, seed: 8, straight: true);
      case NoteTemplate.blossomPage:
        _blossoms(canvas, size, accent);
        _handRules(canvas, size, const Color(0xFF8C8C8C), seed: 4,
            straight: true);
      case NoteTemplate.sunTulips:
        _handRules(canvas, size, accent, seed: 6, straight: true);
        _sun(canvas, size);
        _tulips(canvas, size);

      default:
        _softPanel(canvas, rect);
    }
  }

  // --- ruling that looks drawn rather than printed --------------------------

  /// Horizontal rules with a slight wander, as a hand draws them.
  ///
  /// The wander is deterministic from [seed], so a page does not reshuffle its
  /// own lines on every repaint -- which at 60fps reads as the paper shaking.
  void _handRules(
    Canvas canvas,
    Size size,
    Color colour, {
    required int seed,
    bool straight = false,
  }) {
    final gap = math.max(size.height / 26, 8.0);
    final paint = Paint()
      ..color = colour.withValues(alpha: straight ? 0.45 : 0.75)
      ..strokeWidth = math.max(size.width / 300, 0.9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = math.Random(seed);
    for (double y = gap; y < size.height - gap * 0.4; y += gap) {
      if (straight) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        continue;
      }
      final path = Path()..moveTo(0, y);
      final steps = 4;
      final step = size.width / steps;
      for (var i = 1; i <= steps; i++) {
        final drift = (random.nextDouble() - 0.5) * gap * 0.35;
        path.quadraticBezierTo(
          step * (i - 0.5),
          y + drift,
          step * i,
          y + (random.nextDouble() - 0.5) * gap * 0.18,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  /// The vertical rule down an exercise book's left margin.
  void _marginRule(Canvas canvas, Size size, Color colour) {
    final x = size.width * 0.14;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = colour
        ..strokeWidth = math.max(size.width / 260, 1.0),
    );
  }

  /// Squared paper, edge to edge.
  void _squares(Canvas canvas, Size size, Color colour) {
    final cell = math.max(math.min(size.width, size.height) / 18, 7.0);
    final paint = Paint()
      ..color = colour.withValues(alpha: 0.55)
      ..strokeWidth = math.max(size.width / 420, 0.6);
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  // --- things drawn on the page ---------------------------------------------

  /// Two crayon lines looping round the edge, one behind the other.
  void _squiggleBorder(Canvas canvas, Size size, Color dark, Color light) {
    Path loop(double inset) {
      final r = Rect.fromLTWH(size.width * inset, size.height * inset * 0.6,
          size.width * (1 - inset * 2), size.height * (1 - inset * 1.2));
      return Path()
        ..moveTo(r.left, r.top + r.height * 0.18)
        ..cubicTo(r.left + r.width * 0.25, r.top - r.height * 0.06,
            r.left + r.width * 0.55, r.top + r.height * 0.16, r.right,
            r.top + r.height * 0.02)
        ..moveTo(r.left, r.bottom - r.height * 0.16)
        ..cubicTo(r.left + r.width * 0.3, r.bottom + r.height * 0.06,
            r.left + r.width * 0.62, r.bottom - r.height * 0.18, r.right,
            r.bottom - r.height * 0.02);
    }

    final width = math.max(size.width / 60, 2.0);
    canvas.drawPath(
      loop(0.05),
      Paint()
        ..color = light
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      loop(0.08),
      Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.9
        ..strokeCap = StrokeCap.round,
    );
  }

  /// A pale ribbon wandering down the page, with small hearts caught on it.
  void _ribbonHearts(Canvas canvas, Size size, Color ribbon, Color heart) {
    final path = Path()
      ..moveTo(size.width * 0.04, size.height * 0.10)
      ..cubicTo(size.width * 0.34, size.height * 0.02, size.width * 0.22,
          size.height * 0.28, size.width * 0.52, size.height * 0.24)
      ..moveTo(size.width * 0.96, size.height * 0.42)
      ..cubicTo(size.width * 0.66, size.height * 0.50, size.width * 0.92,
          size.height * 0.68, size.width * 0.62, size.height * 0.74)
      ..moveTo(size.width * 0.06, size.height * 0.86)
      ..cubicTo(size.width * 0.30, size.height * 0.78, size.width * 0.24,
          size.height * 0.98, size.width * 0.48, size.height * 0.94);

    canvas.drawPath(
      path,
      Paint()
        ..color = ribbon
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(size.width / 55, 2.2)
        ..strokeCap = StrokeCap.round,
    );

    for (final spot in [
      Offset(size.width * 0.45, size.height * 0.20),
      Offset(size.width * 0.78, size.height * 0.60),
      Offset(size.width * 0.22, size.height * 0.92),
    ]) {
      _heart(canvas, spot, heart, math.max(size.width / 28, 5.0));
    }
  }

  /// A small hand-drawn heart, on its point.
  void _heart(Canvas canvas, Offset centre, Color colour, double size) {
    final path = Path()
      ..moveTo(centre.dx, centre.dy + size * 0.55)
      ..cubicTo(centre.dx - size, centre.dy - size * 0.1, centre.dx - size * 0.35,
          centre.dy - size * 0.85, centre.dx, centre.dy - size * 0.25)
      ..cubicTo(centre.dx + size * 0.35, centre.dy - size * 0.85,
          centre.dx + size, centre.dy - size * 0.1, centre.dx,
          centre.dy + size * 0.55)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  /// A wave drawn round the page as a frame, with hearts pinned to it.
  void _goldWaveFrame(Canvas canvas, Size size, Color gold, Color heart) {
    final rect = Rect.fromLTWH(size.width * 0.08, size.height * 0.06,
        size.width * 0.84, size.height * 0.88);
    canvas.drawPath(
      _wavyRect(rect, amplitude: math.min(size.width, size.height) * 0.035),
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(size.width / 45, 2.6)
        ..strokeJoin = StrokeJoin.round,
    );

    final small = math.max(size.width / 34, 4.0);
    for (final spot in [
      Offset(rect.left + rect.width * 0.30, rect.top),
      Offset(rect.right, rect.top + rect.height * 0.32),
      Offset(rect.left + rect.width * 0.62, rect.bottom),
      Offset(rect.left, rect.top + rect.height * 0.66),
    ]) {
      _heart(canvas, spot, heart, small);
    }
  }

  /// A rainbow washed into one corner, pale enough to write over.
  void _rainbowWash(Canvas canvas, Size size) {
    const bands = [
      Color(0xFFF6C6C6),
      Color(0xFFF8DEB8),
      Color(0xFFF6F0BC),
      Color(0xFFC8E4C4),
      Color(0xFFC2D6EE),
      Color(0xFFDCC8E6),
    ];
    final centre = Offset(-size.width * 0.35, size.height * 0.62);
    final span = size.width * 0.42;
    for (var i = 0; i < bands.length; i++) {
      canvas.drawCircle(
        centre,
        span + (bands.length - i) * (size.width * 0.14),
        Paint()
          ..color = bands[i].withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.14,
      );
    }
  }

  /// Watercolour blossoms: overlapping translucent petals, no outline.
  void _blossoms(Canvas canvas, Size size, Color colour) {
    void bloom(Offset centre, double radius) {
      final petal = Paint()..color = colour.withValues(alpha: 0.38);
      for (var i = 0; i < 5; i++) {
        final angle = (math.pi * 2 / 5) * i - math.pi / 2;
        canvas.drawCircle(
          centre + Offset(math.cos(angle), math.sin(angle)) * radius * 0.62,
          radius * 0.55,
          petal,
        );
      }
      canvas.drawCircle(
        centre,
        radius * 0.26,
        Paint()..color = const Color(0xFFF6D98A).withValues(alpha: 0.75),
      );
    }

    final unit = math.min(size.width, size.height);
    bloom(Offset(size.width * 0.80, size.height * 0.22), unit * 0.22);
    bloom(Offset(size.width * 0.12, size.height * 0.78), unit * 0.26);
  }

  /// A sun in the top corner.
  void _sun(Canvas canvas, Size size) {
    const gold = Color(0xFFF2C230);
    final centre = Offset(size.width * 0.82, size.height * 0.09);
    final radius = math.min(size.width, size.height) * 0.075;
    canvas.drawCircle(centre, radius, Paint()..color = gold);
    final ray = Paint()
      ..color = gold
      ..strokeWidth = math.max(size.width / 90, 1.6)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = (math.pi * 2 / 8) * i;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * radius * 1.45,
        centre + direction * radius * 2.05,
        ray,
      );
    }
  }

  /// Three tulips in the bottom corner.
  void _tulips(Canvas canvas, Size size) {
    const red = Color(0xFFD94A3D);
    const green = Color(0xFF3F7D43);
    final unit = math.min(size.width, size.height);
    final base = Offset(size.width * 0.16, size.height * 0.95);

    // (sideways offset, height as a fraction of the page, head scale)
    for (final spec in <List<double>>[
      [-0.10, 0.13, 0.9],
      [0.0, 0.17, 1.0],
      [0.10, 0.12, 0.85],
    ]) {
      final stemTop =
          base + Offset(unit * spec[0], -size.height * spec[1]);
      canvas.drawLine(
        base + Offset(unit * spec[0] * 0.5, 0),
        stemTop,
        Paint()
          ..color = green
          ..strokeWidth = math.max(unit / 90, 1.4)
          ..strokeCap = StrokeCap.round,
      );

      final head = unit * 0.05 * spec[2];
      final cup = Path()
        ..moveTo(stemTop.dx - head, stemTop.dy)
        ..quadraticBezierTo(
            stemTop.dx, stemTop.dy + head * 1.3, stemTop.dx + head, stemTop.dy)
        ..lineTo(stemTop.dx + head * 0.55, stemTop.dy - head * 1.1)
        ..lineTo(stemTop.dx, stemTop.dy - head * 0.5)
        ..lineTo(stemTop.dx - head * 0.55, stemTop.dy - head * 1.1)
        ..close();
      canvas.drawPath(cup, Paint()..color = red);

      // One leaf per stem, alternating side.
      final leaf = Path()
        ..moveTo(stemTop.dx, stemTop.dy + head * 2.4)
        ..quadraticBezierTo(
          stemTop.dx + head * 2.2 * (spec[0] >= 0 ? 1 : -1),
          stemTop.dy + head * 2.6,
          stemTop.dx,
          stemTop.dy + head * 4.4,
        );
      canvas.drawPath(
        leaf,
        Paint()
          ..color = green
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(unit / 70, 1.6)
          ..strokeCap = StrokeCap.round,
      );
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
