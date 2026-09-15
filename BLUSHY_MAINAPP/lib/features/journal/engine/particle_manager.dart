import 'dart:math';
import 'package:flutter/material.dart';

enum SeasonalTheme { spring, summer, autumn, winter, night }
enum DecorationDensity { low, medium, high }

class AmbientParticle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  double angle;
  double wobbleSpeed;

  AmbientParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.angle,
    required this.wobbleSpeed,
  });
}

class ParticleManager extends ChangeNotifier {
  SeasonalTheme currentSeason = SeasonalTheme.spring;
  DecorationDensity density = DecorationDensity.medium;
  bool isPaused = false;
  bool reducedMotion = false;

  final List<AmbientParticle> particles = [];
  final Random _rnd = Random();

  ParticleManager() {
    _initParticles();
  }

  void setSeason(SeasonalTheme season) {
    if (currentSeason != season) {
      currentSeason = season;
      _initParticles();
      notifyListeners();
    }
  }

  void setDensity(DecorationDensity newDensity) {
    if (density != newDensity) {
      density = newDensity;
      _initParticles();
      notifyListeners();
    }
  }

  void setPaused(bool paused) {
    if (isPaused != paused) {
      isPaused = paused;
      notifyListeners();
    }
  }

  void setReducedMotion(bool reduced) {
    if (reducedMotion != reduced) {
      reducedMotion = reduced;
      _initParticles();
      notifyListeners();
    }
  }

  int get targetParticleCount {
    if (reducedMotion) return 0;
    switch (density) {
      case DecorationDensity.low:
        return 15;
      case DecorationDensity.medium:
        return 30;
      case DecorationDensity.high:
        return 50;
    }
  }

  void _initParticles() {
    particles.clear();
    final count = targetParticleCount;
    for (int i = 0; i < count; i++) {
      particles.add(_createRandomParticle(resetY: false));
    }
  }

  AmbientParticle _createRandomParticle({bool resetY = true}) {
    return AmbientParticle(
      x: _rnd.nextDouble(),
      y: resetY ? -0.1 : _rnd.nextDouble(),
      speed: 0.001 + _rnd.nextDouble() * 0.002,
      size: 4 + _rnd.nextDouble() * 8,
      opacity: 0.15 + _rnd.nextDouble() * 0.35,
      angle: _rnd.nextDouble() * pi * 2,
      wobbleSpeed: 0.5 + _rnd.nextDouble() * 1.5,
    );
  }

  void tick(Size canvasSize) {
    if (isPaused || reducedMotion || particles.isEmpty) return;

    for (var p in particles) {
      p.angle += 0.02 * p.wobbleSpeed;
      switch (currentSeason) {
        case SeasonalTheme.spring: // Petals drift down and sway
          p.y += p.speed;
          p.x += sin(p.angle) * 0.001;
          break;
        case SeasonalTheme.summer: // Floating dust particles drift upward gently
          p.y -= p.speed * 0.5;
          p.x += cos(p.angle) * 0.0008;
          break;
        case SeasonalTheme.autumn: // Drifting leaves fall faster with wider swing
          p.y += p.speed * 1.3;
          p.x += sin(p.angle * 1.5) * 0.002;
          break;
        case SeasonalTheme.winter: // Gentle snow falls straight with slight drift
          p.y += p.speed * 0.8;
          p.x += sin(p.angle * 0.5) * 0.0005;
          break;
        case SeasonalTheme.night: // Fireflies pulse and hover slowly
          p.x += cos(p.angle) * 0.0006;
          p.y += sin(p.angle) * 0.0006;
          p.opacity = (0.2 + sin(p.angle * 2) * 0.25).clamp(0.05, 0.5);
          break;
      }

      // Wrap around bounds
      if (p.y > 1.1) {
        p.y = -0.05;
        p.x = _rnd.nextDouble();
      } else if (p.y < -0.1) {
        p.y = 1.05;
        p.x = _rnd.nextDouble();
      }
      if (p.x > 1.05) p.x = -0.05;
      if (p.x < -0.05) p.x = 1.05;
    }

    notifyListeners();
  }
}
