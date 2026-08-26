import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhotoCardRenderer extends StatefulWidget {
  final dynamic content;
  final String frameStyle;
  final bool enableDevelopingEffect;

  const PhotoCardRenderer({
    super.key,
    required this.content,
    this.frameStyle = 'Polaroid',
    this.enableDevelopingEffect = true,
  });

  @override
  State<PhotoCardRenderer> createState() => _PhotoCardRendererState();
}

class _PhotoCardRendererState extends State<PhotoCardRenderer> with SingleTickerProviderStateMixin {
  late AnimationController _developController;
  late Animation<double> _photoExposureAnim;
  late Animation<double> _captionOpacityAnim;

  @override
  void initState() {
    super.initState();
    _developController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _photoExposureAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _developController, curve: const Interval(0.2, 0.85, curve: Curves.easeOut)),
    );

    _captionOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _developController, curve: const Interval(0.7, 1.0, curve: Curves.easeIn)),
    );

    if (widget.enableDevelopingEffect) {
      _developController.forward();
    } else {
      _developController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _developController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String imageUrl = '';
    String caption = 'Memory';
    String frame = widget.frameStyle;

    if (widget.content is Map<String, dynamic>) {
      imageUrl = widget.content['url'] ?? '';
      caption = widget.content['caption'] ?? 'Memory';
      frame = widget.content['frameStyle'] ?? widget.frameStyle;
    } else if (widget.content is String) {
      imageUrl = widget.content;
    }

    BoxDecoration frameDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
    );

    if (frame.toLowerCase().contains('neon')) {
      frameDecoration = BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF472B6), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFFEC4899), blurRadius: 12, spreadRadius: 1)],
      );
    } else if (frame.toLowerCase().contains('gold')) {
      frameDecoration = BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD97706), width: 2),
        boxShadow: const [BoxShadow(color: Color(0xFFF59E0B), blurRadius: 8, offset: Offset(0, 3))],
      );
    } else if (frame.toLowerCase().contains('vintage')) {
      frameDecoration = BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB45309), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      );
    }

    return AnimatedBuilder(
      animation: _developController,
      builder: (context, child) {
        final exposure = _photoExposureAnim.value;
        final captionOpacity = _captionOpacityAnim.value;

        return Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
          decoration: frameDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo frame housing with Fairy Lights / Neon / Shimmer overlay
              Stack(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Color.lerp(const Color(0xFF1E293B), const Color(0xFFE2E8F0), exposure),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Opacity(
                            opacity: exposure,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(Icons.image_rounded, size: 40, color: Colors.grey),
                            ),
                          )
                        : Opacity(
                            opacity: exposure,
                            child: const Icon(Icons.image_rounded, size: 40, color: Colors.grey),
                          ),
                  ),

                  // Fairy Lights LED blink effect if frame == Fairy Lights
                  if (frame.toLowerCase().contains('fairy')) ...[
                    Positioned(
                      top: 4,
                      left: 6,
                      child: _buildBlinkingLED(Colors.amber),
                    ),
                    Positioned(
                      top: 4,
                      right: 6,
                      child: _buildBlinkingLED(Colors.pinkAccent),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 6,
                      child: _buildBlinkingLED(Colors.lightBlueAccent),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: _buildBlinkingLED(Colors.lightGreenAccent),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: captionOpacity,
                child: Text(
                  caption,
                  style: GoogleFonts.caveat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: frame.toLowerCase().contains('neon') ? const Color(0xFFF472B6) : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlinkingLED(Color color) {
    final t = (DateTime.now().millisecondsSinceEpoch % 1200) / 1200.0;
    final opacity = 0.3 + 0.7 * sin(t * pi * 2).abs();
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 4)],
      ),
    );
  }
}
