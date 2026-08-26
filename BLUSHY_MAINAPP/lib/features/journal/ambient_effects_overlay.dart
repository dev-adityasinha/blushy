import 'dart:math';
import 'package:flutter/material.dart';
import 'engine/particle_manager.dart';

class AmbientEffectsOverlay extends StatefulWidget {
  final ParticleManager particleManager;
  final Size canvasSize;

  const AmbientEffectsOverlay({
    super.key,
    required this.particleManager,
    required this.canvasSize,
  });

  @override
  State<AmbientEffectsOverlay> createState() => _AmbientEffectsOverlayState();
}

class _AmbientEffectsOverlayState extends State<AmbientEffectsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _ticker.addListener(_onFrameTick);
  }

  void _onFrameTick() {
    if (mounted && !widget.particleManager.isPaused && !widget.particleManager.reducedMotion) {
      widget.particleManager.tick(widget.canvasSize);
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onFrameTick);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.particleManager,
        builder: (context, _) {
          if (widget.particleManager.reducedMotion || widget.particleManager.particles.isEmpty) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: widget.canvasSize,
            painter: _ParticlePainter(
              particles: widget.particleManager.particles,
              season: widget.particleManager.currentSeason,
            ),
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<AmbientParticle> particles;
  final SeasonalTheme season;

  _ParticlePainter({required this.particles, required this.season});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      final dx = p.x * size.width;
      final dy = p.y * size.height;

      switch (season) {
        case SeasonalTheme.spring: // Sakura petals
          paint.color = const Color(0xFFFFB7B2).withValues(alpha: p.opacity);
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(p.angle);
          final path = Path()
            ..moveTo(0, -p.size)
            ..quadraticBezierTo(p.size * 0.8, -p.size * 0.2, 0, p.size)
            ..quadraticBezierTo(-p.size * 0.8, -p.size * 0.2, 0, -p.size);
          canvas.drawPath(path, paint);
          canvas.restore();
          break;

        case SeasonalTheme.summer: // Floating golden dust
          paint.color = const Color(0xFFFDE68A).withValues(alpha: p.opacity * 0.7);
          canvas.drawCircle(Offset(dx, dy), p.size * 0.35, paint);
          break;

        case SeasonalTheme.autumn: // Maple / oak leaf shapes
          paint.color = const Color(0xFFF97316).withValues(alpha: p.opacity);
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate(p.angle);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
          canvas.restore();
          break;

        case SeasonalTheme.winter: // Soft snow circles
          paint.color = Colors.white.withValues(alpha: p.opacity * 0.8);
          canvas.drawCircle(Offset(dx, dy), p.size * 0.4, paint);
          break;

        case SeasonalTheme.night: // Pulsing fireflies
          paint.color = const Color(0xFFFEF08A).withValues(alpha: p.opacity);
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.5);
          canvas.drawCircle(Offset(dx, dy), p.size * 0.5, paint);
          paint.maskFilter = null;
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
