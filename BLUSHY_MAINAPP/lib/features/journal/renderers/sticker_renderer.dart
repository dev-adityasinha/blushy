import 'dart:math';
import 'package:flutter/material.dart';

class StickerRenderer extends StatefulWidget {
  final dynamic content;
  final Color? customColor;
  final bool isAnimated;

  const StickerRenderer({
    super.key,
    required this.content,
    this.customColor,
    this.isAnimated = true,
  });

  @override
  State<StickerRenderer> createState() => _StickerRendererState();
}

class _StickerRendererState extends State<StickerRenderer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isAnimated) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StickerRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated != oldWidget.isAnimated) {
      if (widget.isAnimated) {
        _animController.repeat(reverse: true);
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

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.star_rounded;
    Color color = widget.customColor ?? Colors.amber;
    String name = 'star';

    if (widget.content is Map<String, dynamic>) {
      icon = widget.content['icon'] as IconData? ?? Icons.star_rounded;
      color = widget.customColor ?? (widget.content['color'] as Color? ?? Colors.amber);
      name = (widget.content['name'] as String? ?? 'star').toLowerCase();
    } else if (widget.content is String) {
      name = (widget.content as String).toLowerCase();
    }

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final t = _animController.value;
        Widget animatedChild = Icon(icon, size: 42, color: color);

        if (!widget.isAnimated) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: animatedChild,
          );
        }

        // Apply specific micro animation based on sticker type
        if (name.contains('butterfly')) { // Slow wing flapping
          final scaleX = 0.65 + 0.35 * cos(t * pi * 2);
          animatedChild = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scaleByDouble(scaleX, 1.0, 1.0, 1.0),
            child: animatedChild,
          );
        } else if (name.contains('flower') || name.contains('leaf')) { // Gentle sway / drift
          final angle = sin(t * pi * 2) * 0.08;
          animatedChild = Transform.rotate(angle: angle, child: animatedChild);
        } else if (name.contains('daisy') || name.contains('moon')) { // Breathing pulse
          final scale = 0.95 + 0.1 * sin(t * pi);
          animatedChild = Transform.scale(scale: scale, child: animatedChild);
        } else if (name.contains('star') || name.contains('sparkle')) { // Twinkle fade
          final opacity = 0.5 + 0.5 * sin(t * pi * 2);
          animatedChild = Opacity(opacity: opacity, child: animatedChild);
        } else if (name.contains('cloud') || name.contains('balloon')) { // Floating motion
          final offsetY = -3.0 + 6.0 * sin(t * pi * 2);
          animatedChild = Transform.translate(offset: Offset(0, offsetY), child: animatedChild);
        } else if (name.contains('sun')) { // Rotating light rays
          final angle = t * pi * 2;
          animatedChild = Transform.rotate(angle: angle, child: animatedChild);
        } else if (name.contains('heart')) { // Heartbeat pulse
          final scale = 1.0 + (sin(t * pi * 4) > 0.6 ? 0.12 : 0.0);
          animatedChild = Transform.scale(scale: scale, child: animatedChild);
        } else if (name.contains('teddy')) { // Tiny bounce
          final offsetY = -2.0 * sin(t * pi * 2).abs();
          animatedChild = Transform.translate(offset: Offset(0, offsetY), child: animatedChild);
        }

        return Container(
          padding: const EdgeInsets.all(8),
          child: animatedChild,
        );
      },
    );
  }
}
