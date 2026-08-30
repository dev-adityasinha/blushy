import 'dart:math' as math;
import 'package:flutter/material.dart';

class PetalData {
  double x;
  double y;
  double size;
  double speedY;
  double speedX;
  double rotation;
  double rotSpeed;
  double wobble;
  double wobbleSpeed;
  Color color;

  PetalData({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
    required this.speedX,
    required this.rotation,
    required this.rotSpeed,
    required this.wobble,
    required this.wobbleSpeed,
    required this.color,
  });
}

class FallingPetals extends StatefulWidget {
  const FallingPetals({super.key});

  @override
  State<FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<FallingPetals> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<PetalData> _petals = [];
  final math.Random _random = math.Random();

  final List<Color> _petalColors = [
    const Color(0x4DE8A0B4), // rgba(232, 160, 180, 0.3)
    const Color(0x40F2C6D0), // rgba(242, 198, 208, 0.25)
    const Color(0x33C89B7B), // rgba(200, 155, 123, 0.2)
    const Color(0x338FB996), // rgba(143, 185, 150, 0.2)
    const Color(0x33D4A574), // rgba(212, 165, 116, 0.2)
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_updatePetals);
    
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_petals.isEmpty) {
      final size = MediaQuery.of(context).size;
      const count = 18;
      for (int i = 0; i < count; i++) {
        _petals.add(_createPetal(size.width, size.height, isInitial: true));
      }
    }
  }

  PetalData _createPetal(double width, double height, {bool isInitial = false}) {
    return PetalData(
      x: _random.nextDouble() * width,
      y: isInitial ? _random.nextDouble() * height : -20.0,
      size: _random.nextDouble() * 12 + 6,
      speedY: _random.nextDouble() * 0.6 + 0.2,
      speedX: (_random.nextDouble() - 0.5) * 0.4,
      rotation: _random.nextDouble() * 360,
      rotSpeed: (_random.nextDouble() - 0.5) * 1.5,
      wobble: _random.nextDouble() * math.pi * 2,
      wobbleSpeed: _random.nextDouble() * 0.02 + 0.01,
      color: _petalColors[_random.nextInt(_petalColors.length)],
    );
  }

  void _updatePetals() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    for (var petal in _petals) {
      petal.y += petal.speedY * 1.5; // Scale speed for Flutter refresh
      petal.wobble += petal.wobbleSpeed;
      petal.x += petal.speedX + math.sin(petal.wobble) * 0.5;
      petal.rotation += petal.rotSpeed;

      if (petal.y > size.height + 20) {
        petal.y = -20;
        petal.x = _random.nextDouble() * size.width;
      }
      if (petal.x > size.width + 20) petal.x = -20;
      if (petal.x < -20) petal.x = size.width + 20;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PetalsPainter(_petals),
        ),
      ),
    );
  }
}

class _PetalsPainter extends CustomPainter {
  final List<PetalData> petals;

  _PetalsPainter(this.petals);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in petals) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation * math.pi / 180);
      paint.color = p.color;

      // Draw ellipse shape for flower petal
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size * 2,
        height: p.size / 1.25,
      );
      canvas.drawOval(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
