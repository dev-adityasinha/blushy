import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum DeskSurfaceTheme { wood, marble, pink, dark, vintage }

class DeskEnvironmentWidget extends StatefulWidget {
  final DeskSurfaceTheme surfaceTheme;
  final Widget child;
  final bool enableAnimations;

  const DeskEnvironmentWidget({
    super.key,
    required this.surfaceTheme,
    required this.child,
    this.enableAnimations = true,
  });

  @override
  State<DeskEnvironmentWidget> createState() => _DeskEnvironmentWidgetState();
}

class _DeskEnvironmentWidgetState extends State<DeskEnvironmentWidget> with TickerProviderStateMixin {
  late AnimationController _animController;
  bool _isLampOn = true;
  bool _stickyFlutter = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.enableAnimations) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DeskEnvironmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimations != oldWidget.enableAnimations) {
      if (widget.enableAnimations) {
        _animController.repeat();
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  BoxDecoration _getDeskBackground() {
    switch (widget.surfaceTheme) {
      case DeskSurfaceTheme.wood:
        return const BoxDecoration(
          color: Color(0xFF3E2723),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF5D4037), Color(0xFF2C1A16)],
          ),
        );
      case DeskSurfaceTheme.marble:
        return const BoxDecoration(
          color: Color(0xFFECEFF1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFCFD8DC)],
          ),
        );
      case DeskSurfaceTheme.pink:
        return const BoxDecoration(
          color: Color(0xFFFCE4EC),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0F5), Color(0xFFF8BBD0)],
          ),
        );
      case DeskSurfaceTheme.dark:
        return const BoxDecoration(
          color: Color(0xFF121212),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Color(0xFF263238), Color(0xFF0D1117)],
          ),
        );
      case DeskSurfaceTheme.vintage:
        return const BoxDecoration(
          color: Color(0xFF4A3728),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5C4033), Color(0xFF2B1D14)],
          ),
        );
    }
  }

  BoxDecoration _getLightingOverlay() {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).hour;

    if (hour >= 5 && hour < 12) {
      // Morning Warm Sunlight from left
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ),
      );
    } else if (hour >= 12 && hour < 17) {
      // Afternoon Bright Daylight
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
      );
    } else if (hour >= 17 && hour < 20) {
      // Golden Hour Evening
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.deepOrangeAccent.withValues(alpha: 0.15),
            Colors.amber.withValues(alpha: 0.08),
          ],
        ),
      );
    } else {
      // Evening / Night Glow from Lamp
      return BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.8, -0.8),
          radius: 1.3,
          colors: [
            _isLampOn ? Colors.orangeAccent.withValues(alpha: 0.28) : Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final swayOffset = widget.enableAnimations ? math.sin(_animController.value * 2 * math.pi) * 3.0 : 0.0;

        return Container(
          decoration: _getDeskBackground(),
          child: Stack(
            children: [
              // Dynamic Time-of-Day & Lamp Lighting Overlay
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  decoration: _getLightingOverlay(),
                ),
              ),

              // Top Left Desk Accessory: Indoor Plant (Gentle Sway) & Sticky Notes (Flutter on tap)
              Positioned(
                left: 20,
                top: 24,
                child: Opacity(
                  opacity: 0.88,
                  child: Row(
                    children: [
                      // Plant with RepaintBoundary and Sine Sway
                      RepaintBoundary(
                        child: Transform.translate(
                          offset: Offset(swayOffset, 0),
                          child: const Icon(Icons.eco_rounded, color: Color(0xFF66BB6A), size: 36),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Sticky Note Flutter
                      GestureDetector(
                        onTap: () {
                          setState(() => _stickyFlutter = !_stickyFlutter);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          transform: Matrix4.rotationZ(_stickyFlutter ? 0.08 : 0.0),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF08A),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                          ),
                          child: Text(
                            '📌 Remember:\nWrite 1 line today',
                            style: GoogleFonts.architectsDaughter(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Right Desk Accessory: Interactive Lamp & Steaming Coffee Mug
              Positioned(
                right: 20,
                top: 20,
                child: Opacity(
                  opacity: 0.9,
                  child: Row(
                    children: [
                      // Interactive Desk Lamp (Tap to toggle light)
                      GestureDetector(
                        onTap: () => setState(() => _isLampOn = !_isLampOn),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isLampOn ? const Color(0xFFD97706) : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow: _isLampOn ? const [BoxShadow(color: Colors.orangeAccent, blurRadius: 12)] : [],
                          ),
                          child: Icon(
                            _isLampOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Coffee Mug with RepaintBoundary Steam Animation
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (widget.enableAnimations)
                            Positioned(
                              top: -12,
                              left: 8,
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  size: const Size(16, 16),
                                  painter: _SteamPainter(_animController.value),
                                ),
                              ),
                            ),
                          const Icon(Icons.coffee_rounded, color: Color(0xFFD7CCC8), size: 32),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Desk Accessory: Glasses & Fountain Pen
              Positioned(
                left: 30,
                bottom: 30,
                child: Opacity(
                  opacity: 0.8,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, color: Color(0xFFD4AF37), size: 28),
                      const SizedBox(width: 16),
                      Text('👓 Reading Glasses', style: GoogleFonts.manrope(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ),
              ),

              // Center Child Content (Diary Cover / Editor)
              Positioned.fill(
                child: Center(child: widget.child),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SteamPainter extends CustomPainter {
  final double animValue;
  _SteamPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final yOffset = (1.0 - animValue) * size.height;
    path.moveTo(size.width * 0.3, size.height + yOffset);
    path.cubicTo(
      size.width * 0.6,
      size.height * 0.6 + yOffset,
      0,
      size.height * 0.3 + yOffset,
      size.width * 0.4,
      yOffset,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SteamPainter oldDelegate) => true;
}
