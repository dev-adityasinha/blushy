import 'package:flutter/material.dart';

class WashiTapeRenderer extends StatelessWidget {
  final Color color;
  final String style;

  const WashiTapeRenderer({
    super.key,
    required this.color,
    this.style = 'Classic',
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;

    switch (style.toLowerCase()) {
      case 'gold foil':
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFFEF08A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        );
        break;
      case 'holographic':
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA5F3FC), Color(0xFFFBCFE8), Color(0xFFDDD6FE)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        );
        break;
      case 'rainbow':
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFCA5A5), Color(0xFFFDE047), Color(0xFF86EFAC), Color(0xFF93C5FD)],
          ),
          borderRadius: BorderRadius.circular(1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
        );
        break;
      case 'kraft':
        decoration = BoxDecoration(
          color: const Color(0xFFD97706).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
        );
        break;
      case 'transparent':
        decoration = BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          border: Border.all(color: Colors.white54, width: 0.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        );
        break;
      case 'grid':
        decoration = BoxDecoration(
          color: color.withValues(alpha: 0.75),
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
        );
        break;
      default: // Floral / Vintage / Newspaper / Standard color
        decoration = BoxDecoration(
          color: color.withValues(alpha: 0.78),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1.5))],
        );
        break;
    }

    return Container(
      width: 120,
      height: 26,
      decoration: decoration,
      child: Stack(
        children: [
          // Jagged torn edge simulation on left & right
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: Colors.black.withValues(alpha: 0.05)),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: Colors.black.withValues(alpha: 0.05)),
          ),
        ],
      ),
    );
  }
}
