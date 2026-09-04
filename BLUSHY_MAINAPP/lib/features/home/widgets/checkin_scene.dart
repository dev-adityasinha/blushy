import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

/// The little animated scene on a check-in card.
///
/// One per metric, so the card shows what it is asking about rather than an
/// icon: a figure drinking for water, running for movement, asleep for sleep.
///
/// Drawn and animated in code rather than shipped as Lottie or video. The
/// references are other people's artwork, and a drawn scene also takes the
/// card's own palette, scales to any card size, and adds nothing to the bundle.
enum CheckinScene {
  water,
  sleep,
  movement,
  stress,
  energy;

  /// The scene that belongs to a check-in metric.
  static CheckinScene forMetric(String metric) {
    switch (metric) {
      case 'water':
        return CheckinScene.water;
      case 'sleep':
        return CheckinScene.sleep;
      case 'exercise':
        return CheckinScene.movement;
      case 'stress':
        return CheckinScene.stress;
      case 'energy':
        return CheckinScene.energy;
      default:
        // Every follow-up metric has one, and the guard test holds that true.
        // A metric added without a scene gets the calmest of them rather than
        // an empty card.
        return CheckinScene.stress;
    }
  }

  /// The card's ground.
  Color get colour => switch (this) {
        // The three brand hues, per the palette. Two scenes share a hue;
        // the drawing and the label tell them apart, as they must anyway.
        // The soft pink on its own is too light to carry white text (the
        // contrast guard measures it); water takes a deeper rose mixed from
        // the pink and the red, so it stays in the family and stays legible.
        CheckinScene.water => Color.lerp(BlushyColors.secondary, BlushyColors.primary, 0.45)!,
        CheckinScene.sleep => BlushyColors.primary,
        CheckinScene.movement => BlushyColors.accent,
        CheckinScene.stress => BlushyColors.primary,
        CheckinScene.energy => BlushyColors.accent,
      };

  /// The word on the chip at the top of the card.
  String get label => switch (this) {
        CheckinScene.water => 'Water',
        CheckinScene.sleep => 'Sleep',
        CheckinScene.movement => 'Activity',
        CheckinScene.stress => 'Stress',
        CheckinScene.energy => 'Energy',
      };
}

/// Paints one scene at a point in its loop.
///
/// [t] runs 0..1 and repeats. Everything is derived from it, so the painter
/// holds no state and a card rebuilt mid-animation carries on rather than
/// starting again.
class CheckinScenePainter extends CustomPainter {
  CheckinScenePainter({required this.scene, required this.t});

  final CheckinScene scene;
  final double t;

  // The figure, in one flat palette so the scenes read as a set.
  static const Color _skin = Color(0xFFF0C9A4);
  static const Color _hair = Color(0xFF4A3428);
  static const Color _clothes = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Everything is laid out against the shorter side, so a scene keeps its
    // proportions whatever shape the card ends up.
    final unit = math.min(size.width, size.height) / 10;
    final centre = Offset(size.width / 2, size.height / 2);

    _backdrop(canvas, size, unit);

    switch (scene) {
      case CheckinScene.water:
        _water(canvas, centre, unit);
      case CheckinScene.sleep:
        _sleep(canvas, centre, unit);
      case CheckinScene.movement:
        _movement(canvas, centre, unit);
      case CheckinScene.stress:
        _stress(canvas, centre, unit);
      case CheckinScene.energy:
        _energy(canvas, centre, unit);
    }
  }

  /// Soft shapes behind the figure, so it is not standing on nothing.
  void _backdrop(Canvas canvas, Size size, double unit) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.30),
      unit * 2.4,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.24),
      unit * 1.6,
      paint,
    );
    // The ground she stands on.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.78),
        width: unit * 7,
        height: unit * 1.1,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
  }

  // --- the figure -----------------------------------------------------------

  /// Head, body and hair. Arms and legs are drawn by each scene, because that
  /// is where the movement is.
  void _torso(Canvas canvas, Offset hip, double unit, {double lean = 0}) {
    final shoulder = hip + Offset(lean * unit, -unit * 1.9);
    final head = shoulder + Offset(lean * unit * 0.4, -unit * 1.15);

    canvas.drawLine(
      hip,
      shoulder,
      Paint()
        ..color = _clothes
        ..strokeWidth = unit * 1.25
        ..strokeCap = StrokeCap.round,
    );
    _head(canvas, head, unit);
  }

  /// A head with hair long enough to read as a woman's.
  ///
  /// The figure was a circle with a cap arc on it, which reads as nobody in
  /// particular. Length past the shoulders is the cheapest thing that fixes
  /// that at this size -- features would be too small to carry it.
  void _head(Canvas canvas, Offset head, double unit, {double sweep = 1}) {
    final hair = Paint()..color = _hair;

    // Behind the face, falling to the shoulders on both sides.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: head + Offset(0, unit * 0.85 * sweep),
          width: unit * 1.42,
          height: unit * 2.0,
        ),
        Radius.circular(unit * 0.55),
      ),
      hair,
    );

    canvas.drawCircle(head, unit * 0.78, Paint()..color = _skin);

    // And over the crown, so the face sits inside it.
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: unit * 0.82),
      math.pi,
      math.pi,
      true,
      hair,
    );
  }

  void _limb(Canvas canvas, Offset from, Offset to, double unit, Color colour) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = colour
        ..strokeWidth = unit * 0.42
        ..strokeCap = StrokeCap.round,
    );
  }

  // --- the scenes -----------------------------------------------------------

  /// Raising a glass and drinking from it.
  void _water(Canvas canvas, Offset centre, double unit) {
    // One slow tilt and back per loop.
    final tilt = math.sin(t * math.pi * 2).clamp(0.0, 1.0);
    final hip = centre + Offset(-unit * 0.4, unit * 1.6);

    _torso(canvas, hip, unit);
    final shoulder = hip + const Offset(0, 0) + Offset(0, -unit * 1.9);
    final head = shoulder + Offset(0, -unit * 1.15);

    // The far arm rests; the near one lifts the glass to the mouth.
    _limb(canvas, shoulder, shoulder + Offset(-unit * 1.1, unit * 1.2), unit,
        _skin);

    final glassAt = Offset.lerp(
      shoulder + Offset(unit * 1.5, unit * 0.9),
      head + Offset(unit * 0.75, unit * 0.05),
      tilt,
    )!;
    _limb(canvas, shoulder, glassAt, unit, _skin);

    // Legs.
    _limb(canvas, hip, hip + Offset(-unit * 0.55, unit * 1.9), unit, _clothes);
    _limb(canvas, hip, hip + Offset(unit * 0.55, unit * 1.9), unit, _clothes);

    // The glass, tipping as it reaches the mouth.
    canvas.save();
    canvas.translate(glassAt.dx, glassAt.dy);
    canvas.rotate(-tilt * 0.7);
    final glass = Rect.fromCenter(
      center: Offset(0, -unit * 0.55),
      width: unit * 0.95,
      height: unit * 1.25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, Radius.circular(unit * 0.16)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    // The level drops as it is drunk.
    final level = glass.height * (0.72 - tilt * 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            glass.left, glass.bottom - level, glass.width, math.max(0, level)),
        Radius.circular(unit * 0.16),
      ),
      Paint()..color = Color.lerp(Colors.white, BlushyColors.secondary, 0.55)!,
    );
    canvas.restore();

    // A couple of droplets rising, to say the scene is moving even mid-tilt.
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      canvas.drawCircle(
        centre + Offset(unit * (1.9 + i * 0.5), unit * (1.2 - phase * 3)),
        unit * 0.16,
        Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - phase)),
      );
    }
  }

  /// Asleep, with the breath rising and falling.
  void _sleep(Canvas canvas, Offset centre, double unit) {
    final breath = math.sin(t * math.pi * 2) * 0.5 + 0.5;

    // A pillow and a cover; she is lying down, so the figure is on its side.
    final bed = Rect.fromCenter(
      center: centre + Offset(0, unit * 1.4),
      width: unit * 7,
      height: unit * 1.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bed, Radius.circular(unit * 0.5)),
      Paint()..color = Colors.white.withValues(alpha: 0.90),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bed.left, bed.top + unit * 0.5 - breath * unit * 0.12,
            bed.width * 0.72, bed.height * 0.7),
        Radius.circular(unit * 0.4),
      ),
      Paint()..color = Color.lerp(BlushyColors.background, BlushyColors.primary, 0.25)!,
    );

    // Head on the pillow, overlapping the bed rather than perched on its
    // corner, which read as a head floating beside a bar.
    final head = Offset(bed.right - unit * 1.15, bed.top + unit * 0.25);
    // Lying down, so the hair falls across the pillow rather than downwards.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: head + Offset(unit * 0.75, unit * 0.15),
          width: unit * 1.9,
          height: unit * 1.3,
        ),
        Radius.circular(unit * 0.5),
      ),
      Paint()..color = _hair,
    );
    canvas.drawCircle(head, unit * 0.78, Paint()..color = _skin);
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: unit * 0.82),
      math.pi,
      math.pi,
      true,
      Paint()..color = _hair,
    );
    // A closed eye.
    canvas.drawArc(
      Rect.fromCircle(center: head + Offset(unit * 0.1, unit * 0.15),
          radius: unit * 0.22),
      0,
      math.pi,
      false,
      Paint()
        ..color = _hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.09,
    );

    // Zs drifting up and fading.
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      _letterZ(
        canvas,
        head + Offset(unit * (0.9 + phase * 1.2), -unit * (0.9 + phase * 2.4)),
        unit * (0.34 + i * 0.06),
        Colors.white.withValues(alpha: 0.85 * (1 - phase)),
      );
    }
  }

  void _letterZ(Canvas canvas, Offset at, double size, Color colour) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = size * 0.28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(at.dx - size / 2, at.dy - size / 2)
      ..lineTo(at.dx + size / 2, at.dy - size / 2)
      ..lineTo(at.dx - size / 2, at.dy + size / 2)
      ..lineTo(at.dx + size / 2, at.dy + size / 2);
    canvas.drawPath(path, paint);
  }

  /// Running, with the ground moving under her.
  void _movement(Canvas canvas, Offset centre, double unit) {
    // Never allowed to reach zero: at the rest points of a pure sine the limbs
    // meet and the figure reads as standing still, which is the one thing this
    // scene must not look like.
    final swing = math.sin(t * math.pi * 2);
    final stride = swing.isNegative ? swing - 0.35 : swing + 0.35;
    final bob = math.sin(t * math.pi * 4).abs() * unit * 0.18;
    final hip = centre + Offset(-unit * 0.2, unit * 1.4 - bob);

    // Speed lines, so the run reads even in a still frame.
    for (int i = 0; i < 3; i++) {
      final phase = (t * 2 + i / 3) % 1;
      final y = centre.dy - unit * 0.6 + i * unit * 0.9;
      canvas.drawLine(
        Offset(centre.dx - unit * (2.6 + phase * 1.6), y),
        Offset(centre.dx - unit * (1.6 + phase * 1.6), y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35 * (1 - phase))
          ..strokeWidth = unit * 0.16
          ..strokeCap = StrokeCap.round,
      );
    }

    _torso(canvas, hip, unit, lean: 0.35);
    final shoulder = hip + Offset(0.35 * unit, -unit * 1.9);

    // Arms and legs swing opposite each other.
    // Drawn wider of the body than the legs are, so they clear the torso
    // instead of disappearing into it.
    _limb(canvas, shoulder,
        shoulder + Offset(unit * 1.25 * stride, unit * 0.75), unit, _skin);
    _limb(canvas, shoulder,
        shoulder + Offset(-unit * 1.25 * stride, unit * 0.75), unit, _skin);
    _limb(canvas, hip, hip + Offset(unit * 1.1 * stride, unit * 1.8), unit,
        _clothes);
    _limb(canvas, hip, hip + Offset(-unit * 1.1 * stride, unit * 1.8), unit,
        _clothes);
  }

  /// Sitting and breathing, with calm rings going out.
  void _stress(Canvas canvas, Offset centre, double unit) {
    final breath = math.sin(t * math.pi * 2) * 0.5 + 0.5;
    final hip = centre + Offset(0, unit * 1.7);

    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      canvas.drawCircle(
        centre + Offset(0, -unit * 0.2),
        unit * (1.4 + phase * 2.6),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22 * (1 - phase))
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.14,
      );
    }

    // Crossed legs, as a low wide base.
    _limb(canvas, hip + Offset(-unit * 1.3, unit * 0.5),
        hip + Offset(unit * 1.3, unit * 0.5), unit, _clothes);

    _torso(canvas, hip, unit);
    final shoulder = hip + Offset(0, -unit * 1.9);
    // Hands resting on the knees, lifting a little on the in-breath.
    _limb(canvas, shoulder,
        hip + Offset(-unit * 1.15, unit * 0.3 - breath * unit * 0.1), unit,
        _skin);
    _limb(canvas, shoulder,
        hip + Offset(unit * 1.15, unit * 0.3 - breath * unit * 0.1), unit,
        _skin);
  }

  /// Arms up, with sparks coming off.
  void _energy(Canvas canvas, Offset centre, double unit) {
    final lift = math.sin(t * math.pi * 2) * 0.5 + 0.5;
    final hip = centre + Offset(0, unit * 1.6);

    _torso(canvas, hip, unit);
    final shoulder = hip + Offset(0, -unit * 1.9);

    // Both arms rise together.
    for (final side in [-1.0, 1.0]) {
      _limb(
        canvas,
        shoulder,
        shoulder +
            Offset(unit * 1.25 * side, -unit * (0.4 + lift * 0.9)),
        unit,
        _skin,
      );
    }
    _limb(canvas, hip, hip + Offset(-unit * 0.55, unit * 1.9), unit, _clothes);
    _limb(canvas, hip, hip + Offset(unit * 0.55, unit * 1.9), unit, _clothes);

    // Sparks, brightest at the top of the lift.
    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * math.pi * 2 + t * math.pi;
      final at = centre +
          Offset(math.cos(angle), math.sin(angle)) * unit * (2.4 + lift * 0.5);
      canvas.drawCircle(
        at,
        unit * 0.18,
        Paint()..color = Colors.white.withValues(alpha: 0.35 + lift * 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CheckinScenePainter old) =>
      old.t != t || old.scene != scene;
}
