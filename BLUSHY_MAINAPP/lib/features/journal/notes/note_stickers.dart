import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The drawn stickers, and the painter that puts them on a page.
///
/// Stickers were emoji: whatever the device's font happened to draw, at
/// whatever size and in whatever style, differing between phones. These are
/// drawn by the app, so a note looks the same everywhere and stays sharp at
/// any size.
///
/// Drawn rather than shipped as images, for the reason the papers are: the
/// references are sheets of other people's artwork. Everything here is a
/// generic motif -- a bow, a cherry, a ticket stub. Nothing that carries a
/// brand, a character or an album cover is reproduced.
enum JournalSticker {
  heart('heart', 'Heart'),
  star('star', 'Star'),
  sparkle('sparkle', 'Sparkle'),
  bow('bow', 'Bow'),
  bowGingham('bow-gingham', 'Gingham bow'),
  daisy('daisy', 'Daisy'),
  cherry('cherry', 'Cherries'),
  strawberry('strawberry', 'Strawberry'),
  mushroom('mushroom', 'Mushroom'),
  cookie('cookie', 'Cookie'),
  envelope('envelope', 'Letter'),
  ticket('ticket', 'Ticket'),
  button('button', 'Button'),
  paperclip('paperclip', 'Paper clip'),
  pushPin('push-pin', 'Push pin'),
  washiTape('washi', 'Tape'),
  evilEye('evil-eye', 'Evil eye'),
  butterfly('butterfly', 'Butterfly'),
  discoBall('disco', 'Disco ball'),
  rainbow('rainbow', 'Rainbow'),
  clover('clover', 'Clover'),
  record('record', 'Record');

  const JournalSticker(this.id, this.label);

  final String id;
  final String label;

  static JournalSticker? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final sticker in values) {
      if (sticker.id == id) return sticker;
    }
    // An id from a newer build, or a corrupted record. The note opens without
    // the sticker rather than not at all.
    return null;
  }
}

/// One sticker, drawn to fill [size].
class StickerIcon extends StatelessWidget {
  const StickerIcon({super.key, required this.sticker, required this.size});

  final JournalSticker sticker;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: StickerPainter(sticker)),
      );
}

/// Draws a sticker inside a unit square scaled to the canvas.
///
/// Every shape is written against a 100x100 box and scaled, so one set of
/// coordinates serves the 34px on a page and the 40px in the tray.
class StickerPainter extends CustomPainter {
  const StickerPainter(this.sticker);

  final JournalSticker sticker;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final unit = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * unit) / 2,
      (size.height - 100 * unit) / 2,
    );
    canvas.scale(unit);

    switch (sticker) {
      case JournalSticker.heart:
        _heart(canvas, const Color(0xFFD32F3A));
      case JournalSticker.star:
        _star(canvas, const Color(0xFFF2B01E), points: 5, inner: 0.42);
      case JournalSticker.sparkle:
        _sparkle(canvas, const Color(0xFFE8C25A));
      case JournalSticker.bow:
        _bow(canvas, const Color(0xFFC62B3C), null);
      case JournalSticker.bowGingham:
        _bow(canvas, const Color(0xFF3F6DB5), const Color(0xFFDCE7F7));
      case JournalSticker.daisy:
        _daisy(canvas);
      case JournalSticker.cherry:
        _cherry(canvas);
      case JournalSticker.strawberry:
        _strawberry(canvas);
      case JournalSticker.mushroom:
        _mushroom(canvas);
      case JournalSticker.cookie:
        _cookie(canvas);
      case JournalSticker.envelope:
        _envelope(canvas);
      case JournalSticker.ticket:
        _ticket(canvas);
      case JournalSticker.button:
        _button(canvas);
      case JournalSticker.paperclip:
        _paperclip(canvas);
      case JournalSticker.pushPin:
        _pushPin(canvas);
      case JournalSticker.washiTape:
        _washiTape(canvas);
      case JournalSticker.evilEye:
        _evilEye(canvas);
      case JournalSticker.butterfly:
        _butterfly(canvas);
      case JournalSticker.discoBall:
        _discoBall(canvas);
      case JournalSticker.rainbow:
        _rainbow(canvas);
      case JournalSticker.clover:
        _clover(canvas);
      case JournalSticker.record:
        _record(canvas);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(StickerPainter old) => old.sticker != sticker;

  // --- shared helpers -------------------------------------------------------

  Paint _fill(Color colour) => Paint()..color = colour;

  Paint _stroke(Color colour, double width) => Paint()
    ..color = colour
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // --- the stickers ---------------------------------------------------------

  void _heart(Canvas canvas, Color colour) {
    final path = Path()
      ..moveTo(50, 88)
      ..cubicTo(-8, 50, 10, 8, 50, 32)
      ..cubicTo(90, 8, 108, 50, 50, 88)
      ..close();
    canvas.drawPath(path, _fill(colour));
  }

  void _star(Canvas canvas, Color colour,
      {required int points, required double inner}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = (i.isEven ? 46.0 : 46.0 * inner);
      final angle = (math.pi / points) * i - math.pi / 2;
      final point =
          Offset(50 + math.cos(angle) * radius, 52 + math.sin(angle) * radius);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, _fill(colour));
  }

  /// A four-pointed sparkle, drawn as two crossed lozenges.
  void _sparkle(Canvas canvas, Color colour) {
    Path lozenge(double width, double height) => Path()
      ..moveTo(50, 50 - height)
      ..quadraticBezierTo(50 + width * 0.25, 50 - height * 0.25, 50 + width, 50)
      ..quadraticBezierTo(50 + width * 0.25, 50 + height * 0.25, 50, 50 + height)
      ..quadraticBezierTo(50 - width * 0.25, 50 + height * 0.25, 50 - width, 50)
      ..quadraticBezierTo(50 - width * 0.25, 50 - height * 0.25, 50, 50 - height)
      ..close();

    canvas.drawPath(lozenge(20, 46), _fill(colour));
    canvas.drawPath(lozenge(46, 20), _fill(colour));
  }

  /// A ribbon bow. With [check] set the loops carry a gingham weave.
  void _bow(Canvas canvas, Color colour, Color? check) {
    final left = Path()
      ..moveTo(50, 50)
      ..cubicTo(24, 22, 4, 34, 10, 52)
      ..cubicTo(14, 66, 36, 64, 50, 50)
      ..close();
    final right = Path()
      ..moveTo(50, 50)
      ..cubicTo(76, 22, 96, 34, 90, 52)
      ..cubicTo(86, 66, 64, 64, 50, 50)
      ..close();
    final tails = Path()
      ..moveTo(46, 56)
      ..cubicTo(36, 72, 30, 82, 26, 92)
      ..lineTo(40, 88)
      ..cubicTo(44, 76, 48, 66, 50, 60)
      ..cubicTo(52, 66, 56, 76, 60, 88)
      ..lineTo(74, 92)
      ..cubicTo(70, 82, 64, 72, 54, 56)
      ..close();

    for (final path in [tails, left, right]) {
      canvas.drawPath(path, _fill(colour));
    }

    if (check != null) {
      // The weave, clipped to the loops so it does not stray onto the page.
      canvas.save();
      canvas.clipPath(Path.combine(PathOperation.union, left, right));
      final bar = _fill(check.withValues(alpha: 0.55));
      for (double x = 6; x < 96; x += 12) {
        canvas.drawRect(Rect.fromLTWH(x, 20, 6, 50), bar);
      }
      for (double y = 24; y < 70; y += 12) {
        canvas.drawRect(Rect.fromLTWH(4, y, 92, 6), bar);
      }
      canvas.restore();
    }

    // The knot, over everything.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 50), width: 20, height: 17),
      _fill(colour),
    );
  }

  void _daisy(Canvas canvas) {
    const petal = Color(0xFFFFFFFF);
    const edge = Color(0xFFE9DFD2);
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi * 2 / 6) * i - math.pi / 2;
      final centre = Offset(50 + math.cos(angle) * 26, 50 + math.sin(angle) * 26);
      canvas.drawOval(
        Rect.fromCenter(center: centre, width: 34, height: 34),
        _fill(petal),
      );
      canvas.drawOval(
        Rect.fromCenter(center: centre, width: 34, height: 34),
        _stroke(edge, 1.6),
      );
    }
    canvas.drawCircle(const Offset(50, 50), 15, _fill(const Color(0xFFF2C230)));
  }

  void _cherry(Canvas canvas) {
    const red = Color(0xFFC72A32);
    const green = Color(0xFF4C7A3F);
    canvas.drawPath(
      Path()
        ..moveTo(50, 16)
        ..quadraticBezierTo(34, 34, 30, 58)
        ..moveTo(50, 16)
        ..quadraticBezierTo(66, 36, 70, 58),
      _stroke(green, 4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 18)
        ..quadraticBezierTo(62, 8, 76, 12),
      _stroke(green, 5),
    );
    canvas.drawCircle(const Offset(30, 70), 16, _fill(red));
    canvas.drawCircle(const Offset(70, 70), 16, _fill(red));
    canvas.drawCircle(
        const Offset(25, 65), 4, _fill(Colors.white.withValues(alpha: 0.55)));
  }

  void _strawberry(Canvas canvas) {
    const red = Color(0xFFD23A3A);
    const green = Color(0xFF4C7A3F);
    canvas.drawPath(
      Path()
        ..moveTo(50, 30)
        ..cubicTo(86, 32, 86, 78, 50, 92)
        ..cubicTo(14, 78, 14, 32, 50, 30)
        ..close(),
      _fill(red),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 14)
        ..lineTo(56, 30)
        ..lineTo(74, 24)
        ..lineTo(64, 36)
        ..lineTo(78, 40)
        ..lineTo(50, 40)
        ..lineTo(22, 40)
        ..lineTo(36, 36)
        ..lineTo(26, 24)
        ..lineTo(44, 30)
        ..close(),
      _fill(green),
    );
    final seed = _fill(const Color(0xFFF6E2A8));
    for (final spot in [
      const Offset(38, 50),
      const Offset(60, 50),
      const Offset(50, 64),
      const Offset(34, 68),
      const Offset(66, 68),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: spot, width: 5, height: 8),
        seed,
      );
    }
  }

  void _mushroom(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(34, 54)
        ..lineTo(66, 54)
        ..cubicTo(66, 82, 62, 90, 50, 90)
        ..cubicTo(38, 90, 34, 82, 34, 54)
        ..close(),
      _fill(const Color(0xFFF4E7D4)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 54)
        ..cubicTo(12, 22, 88, 22, 88, 54)
        ..close(),
      _fill(const Color(0xFFC7362F)),
    );
    final dot = _fill(const Color(0xFFFFF6EC));
    canvas.drawCircle(const Offset(34, 42), 6, dot);
    canvas.drawCircle(const Offset(58, 36), 5, dot);
    canvas.drawCircle(const Offset(70, 46), 4, dot);
  }

  void _cookie(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 50), 38, _fill(const Color(0xFFD3A163)));
    final chip = _fill(const Color(0xFF5C3A22));
    for (final spot in [
      const Offset(36, 36),
      const Offset(62, 42),
      const Offset(44, 60),
      const Offset(66, 66),
      const Offset(30, 56),
    ]) {
      canvas.drawCircle(spot, 5.5, chip);
    }
  }

  void _envelope(Canvas canvas) {
    final body = Rect.fromLTWH(10, 26, 80, 50);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      _fill(const Color(0xFFFBF3E6)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      _stroke(const Color(0xFFCDB99C), 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 28)
        ..lineTo(50, 56)
        ..lineTo(90, 28),
      _stroke(const Color(0xFFCDB99C), 2),
    );
    _smallHeart(canvas, const Offset(50, 62), 9, const Color(0xFFC72A32));
  }

  void _ticket(Canvas canvas) {
    final body = Rect.fromLTWH(8, 32, 84, 36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      _fill(const Color(0xFFF6D9DC)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(4)),
      _stroke(const Color(0xFFC1707A), 2),
    );
    // The perforation, and the two bites taken out of the edges.
    canvas.drawPath(
      Path()
        ..moveTo(64, 34)
        ..lineTo(64, 66),
      _stroke(const Color(0xFFC1707A), 1.6),
    );
    final bite = _fill(const Color(0xFFFFFFFF));
    canvas.drawCircle(const Offset(8, 50), 6, bite);
    canvas.drawCircle(const Offset(92, 50), 6, bite);
    final line = _stroke(const Color(0xFFC1707A), 2);
    canvas.drawLine(const Offset(18, 44), const Offset(54, 44), line);
    canvas.drawLine(const Offset(18, 54), const Offset(46, 54), line);
  }

  void _button(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 50), 36, _fill(const Color(0xFFE8C3CE)));
    canvas.drawCircle(
        const Offset(50, 50), 36, _stroke(const Color(0xFFC79AA8), 2));
    canvas.drawCircle(
        const Offset(50, 50), 26, _stroke(const Color(0xFFC79AA8), 1.4));
    final hole = _fill(const Color(0xFFFFFBF8));
    for (final spot in [
      const Offset(40, 40),
      const Offset(60, 40),
      const Offset(40, 60),
      const Offset(60, 60),
    ]) {
      canvas.drawCircle(spot, 5.5, hole);
    }
  }

  void _paperclip(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(36, 82)
        ..lineTo(36, 28)
        ..arcToPoint(const Offset(64, 28),
            radius: const Radius.circular(14), clockwise: true)
        ..lineTo(64, 74)
        ..arcToPoint(const Offset(46, 74),
            radius: const Radius.circular(9), clockwise: true)
        ..lineTo(46, 36),
      _stroke(const Color(0xFF9AA3AC), 7),
    );
  }

  void _pushPin(Canvas canvas) {
    const red = Color(0xFFCE3A32);
    canvas.drawLine(const Offset(50, 56), const Offset(50, 92),
        _stroke(const Color(0xFF9AA3AC), 4));
    canvas.drawPath(
      Path()
        ..moveTo(28, 44)
        ..lineTo(72, 44)
        ..cubicTo(66, 56, 60, 58, 50, 58)
        ..cubicTo(40, 58, 34, 56, 28, 44)
        ..close(),
      _fill(red),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 34), width: 46, height: 22),
      _fill(red),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(42, 30), width: 12, height: 6),
      _fill(Colors.white.withValues(alpha: 0.45)),
    );
  }

  void _washiTape(Canvas canvas) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-0.22);
    canvas.translate(-50, -50);
    final strip = Rect.fromLTWH(4, 38, 92, 24);
    canvas.drawRect(strip, _fill(const Color(0xFFE7B9C6).withValues(alpha: 0.9)));
    // Torn ends: small notches cut back out of each edge.
    final tear = _fill(const Color(0x00000000));
    canvas.saveLayer(strip.inflate(4), Paint());
    canvas.drawRect(strip, _fill(const Color(0xFFE7B9C6)));
    final cut = Paint()
      ..blendMode = BlendMode.clear
      ..color = const Color(0xFF000000);
    for (double y = 38; y < 62; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, 6, 3), cut);
      canvas.drawRect(Rect.fromLTWH(94, y + 3, 6, 3), cut);
    }
    canvas.restore();
    canvas.drawRect(strip, tear);
    canvas.restore();
  }

  void _evilEye(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 50), 36, _fill(const Color(0xFF1B4A8C)));
    canvas.drawCircle(const Offset(50, 50), 25, _fill(const Color(0xFFFFFFFF)));
    canvas.drawCircle(const Offset(50, 50), 16, _fill(const Color(0xFF4FA3C7)));
    canvas.drawCircle(const Offset(50, 50), 8, _fill(const Color(0xFF14213D)));
    canvas.drawCircle(const Offset(44, 44), 3,
        _fill(Colors.white.withValues(alpha: 0.8)));
  }

  void _butterfly(Canvas canvas) {
    const wing = Color(0xFFF0A9C0);
    const edge = Color(0xFFD07C99);
    Path wings(double direction) => Path()
      ..moveTo(50, 50)
      ..cubicTo(50 + 44 * direction, 12, 50 + 52 * direction, 44,
          50 + 16 * direction, 52)
      ..cubicTo(50 + 46 * direction, 58, 50 + 34 * direction, 88, 50, 60)
      ..close();

    for (final direction in [-1.0, 1.0]) {
      canvas.drawPath(wings(direction), _fill(wing));
      canvas.drawPath(wings(direction), _stroke(edge, 1.6));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(50, 54), width: 7, height: 40),
        const Radius.circular(4),
      ),
      _fill(const Color(0xFF4A3B42)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 34)
        ..quadraticBezierTo(40, 20, 34, 18)
        ..moveTo(50, 34)
        ..quadraticBezierTo(60, 20, 66, 18),
      _stroke(const Color(0xFF4A3B42), 2),
    );
  }

  void _discoBall(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 54), 36, _fill(const Color(0xFFB9BEC6)));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(
        center: const Offset(50, 54), radius: 36)));
    final facet = _stroke(const Color(0xFF7C838D), 1.4);
    for (double y = 18; y < 92; y += 9) {
      canvas.drawLine(Offset(10, y), Offset(90, y), facet);
    }
    for (double x = 14; x < 90; x += 9) {
      canvas.drawLine(Offset(x, 16), Offset(x, 92), facet);
    }
    // The highlight that makes it read as a sphere rather than a grid.
    canvas.drawCircle(const Offset(36, 40), 14,
        _fill(Colors.white.withValues(alpha: 0.35)));
    canvas.restore();
    canvas.drawLine(const Offset(50, 18), const Offset(50, 8),
        _stroke(const Color(0xFF7C838D), 3));
  }

  void _rainbow(Canvas canvas) {
    const bands = [
      Color(0xFFE06C6C),
      Color(0xFFE8A85C),
      Color(0xFFE8D06A),
      Color(0xFF7FB07C),
      Color(0xFF6F94C8),
    ];
    for (var i = 0; i < bands.length; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(50, 76), radius: 40.0 - i * 7),
        math.pi,
        math.pi,
        false,
        _stroke(bands[i], 7),
      );
    }
  }

  void _clover(Canvas canvas) {
    const green = Color(0xFF4C8A45);
    for (var i = 0; i < 4; i++) {
      final angle = (math.pi / 2) * i - math.pi / 4;
      final centre = Offset(50 + math.cos(angle) * 20, 46 + math.sin(angle) * 20);
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(angle + math.pi / 2);
      canvas.drawPath(
        Path()
          ..moveTo(0, 18)
          ..cubicTo(-22, 6, -14, -18, 0, -8)
          ..cubicTo(14, -18, 22, 6, 0, 18)
          ..close(),
        _fill(green),
      );
      canvas.restore();
    }
    canvas.drawPath(
      Path()
        ..moveTo(50, 62)
        ..quadraticBezierTo(56, 78, 44, 92),
      _stroke(green, 3.5),
    );
  }

  void _record(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 50), 40, _fill(const Color(0xFF1E1B1A)));
    final groove = _stroke(const Color(0xFF3A3533), 1.2);
    for (var r = 16.0; r < 38; r += 5) {
      canvas.drawCircle(const Offset(50, 50), r, groove);
    }
    canvas.drawCircle(const Offset(50, 50), 13, _fill(const Color(0xFFE4D9C8)));
    canvas.drawCircle(const Offset(50, 50), 3, _fill(const Color(0xFFFFFDFC)));
  }

  /// A small solid heart, for stickers that carry one.
  void _smallHeart(Canvas canvas, Offset centre, double size, Color colour) {
    final path = Path()
      ..moveTo(centre.dx, centre.dy + size * 0.6)
      ..cubicTo(centre.dx - size * 1.5, centre.dy - size * 0.2,
          centre.dx - size * 0.4, centre.dy - size, centre.dx,
          centre.dy - size * 0.3)
      ..cubicTo(centre.dx + size * 0.4, centre.dy - size,
          centre.dx + size * 1.5, centre.dy - size * 0.2, centre.dx,
          centre.dy + size * 0.6)
      ..close();
    canvas.drawPath(path, _fill(colour));
  }
}
