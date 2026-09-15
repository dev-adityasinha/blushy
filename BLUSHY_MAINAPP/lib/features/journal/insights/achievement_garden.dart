import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/journal_storage.dart';
import '../ai/smart_search_service.dart';

/// A garden grown from what has actually been written.
///
/// The three counts used to default to 12, 6 and 8, and both call sites took
/// the defaults -- so the garden showed the same twelve flowers to somebody
/// with no entries at all. They are required now, so a caller cannot pick up
/// invented numbers by leaving them out.
class AchievementGardenWidget extends StatelessWidget {
  final int totalGratitudeEntries;
  final int totalTravelEntries;
  final int totalFamilyEntries;

  const AchievementGardenWidget({
    super.key,
    required this.totalGratitudeEntries,
    required this.totalTravelEntries,
    required this.totalFamilyEntries,
  });

  /// Counts the three from stored entries.
  ///
  /// Travel and family come from the collection classifier the smart search
  /// already uses, which reads the entry text. Gratitude comes from the
  /// template the entry was written on, matched the same loose way
  /// `JournalTemplates` matches it -- the stage lists carry several
  /// gratitude variants.
  factory AchievementGardenWidget.fromEntries(
    List<LocalJournalEntry> entries, {
    Key? key,
  }) {
    final collections = SmartSearchService().categorizeCollections(entries);

    var gratitude = 0;
    for (final entry in entries) {
      final raw = entry.rawJson;
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final name = decoded['templateName']?.toString().toLowerCase() ?? '';
        if (name.contains('gratitude')) gratitude++;
      } catch (_) {
        // An unreadable entry grows nothing rather than a guess.
      }
    }

    return AchievementGardenWidget(
      key: key,
      totalGratitudeEntries: gratitude,
      totalTravelEntries: collections['Travel']?.length ?? 0,
      totalFamilyEntries: collections['Family']?.length ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECFDF5),
      appBar: AppBar(
        title: Text('Reflective Content Garden 🌿', style: GoogleFonts.instrumentSerif(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFECFDF5),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your garden grows organically with the depth & diversity of your reflections.',
              style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF065F46)),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
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
          Text(title, style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF065F46))),
          Text(count, style: GoogleFonts.manrope(fontSize: 10, color: Colors.grey[600])),
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
