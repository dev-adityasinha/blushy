import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AchievementGardenWidget extends StatelessWidget {
  final int totalGratitudeEntries;
  final int totalTravelEntries;
  final int totalFamilyEntries;

  const AchievementGardenWidget({
    super.key,
    this.totalGratitudeEntries = 12,
    this.totalTravelEntries = 6,
    this.totalFamilyEntries = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECFDF5),
      appBar: AppBar(
        title: Text('Reflective Content Garden 🌿', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFECFDF5),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your garden grows organically with the depth & diversity of your reflections.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF065F46)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: _GardenPainter(
                  flowers: totalGratitudeEntries,
                  wildflowers: totalTravelEntries,
                  trees: totalFamilyEntries,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendBadge('🌸 Gratitude', '$totalGratitudeEntries Flowers'),
                _buildLegendBadge('🌼 Travel', '$totalTravelEntries Wildflowers'),
                _buildLegendBadge('🌳 Family', '$totalFamilyEntries Trees'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBadge(String title, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
          Text(count, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _GardenPainter extends CustomPainter {
  final int flowers;
  final int wildflowers;
  final int trees;

  _GardenPainter({required this.flowers, required this.wildflowers, required this.trees});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    // Render Trees (Family reflections)
    for (int i = 0; i < min(trees, 8); i++) {
      final x = 40.0 + i * (size.width / 8);
      final y = size.height * 0.4;
      paint.color = const Color(0xFFB45309);
      canvas.drawRect(Rect.fromLTWH(x - 4, y, 8, 40), paint);
      paint.color = const Color(0xFF047857);
      canvas.drawCircle(Offset(x, y - 10), 22, paint);
    }

    // Render Gratitude Flowers
    for (int i = 0; i < min(flowers, 20); i++) {
      final x = 20.0 + rnd.nextDouble() * (size.width - 40);
      final y = size.height * 0.65 + rnd.nextDouble() * (size.height * 0.25);
      paint.color = const Color(0xFFF472B6);
      canvas.drawCircle(Offset(x, y), 6, paint);
    }

    // Render Travel Wildflowers
    for (int i = 0; i < min(wildflowers, 15); i++) {
      final x = 20.0 + rnd.nextDouble() * (size.width - 40);
      final y = size.height * 0.7 + rnd.nextDouble() * (size.height * 0.2);
      paint.color = const Color(0xFFFBBF24);
      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
