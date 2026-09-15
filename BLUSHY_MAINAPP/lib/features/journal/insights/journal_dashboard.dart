import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../repository/journal_repository.dart';
import '../../../theme/colors.dart';

/// Statistics computed from the journal the user actually wrote.
///
/// Every figure on this screen used to be a literal: "14 Days Active",
/// "12,480 Words", "Average 280 words per entry across 42 journal memories",
/// "34 Photos • 12 Voice Notes", "+18% more reflections than last month", and
/// "You often write during quiet mornings around 8:00 AM". None of it was
/// measured, and the screen is reachable from the journal.
class JournalDashboardWidget extends StatefulWidget {
  const JournalDashboardWidget({super.key});

  @override
  State<JournalDashboardWidget> createState() => _JournalDashboardWidgetState();
}

class _JournalStats {
  const _JournalStats({
    required this.entryCount,
    required this.dayCount,
    required this.wordCount,
    required this.photoCount,
    required this.voiceCount,
  });

  final int entryCount;
  final int dayCount;
  final int wordCount;
  final int photoCount;
  final int voiceCount;

  bool get isEmpty => entryCount == 0;

  int get averageWords => entryCount == 0 ? 0 : (wordCount / entryCount).round();
}

class _JournalDashboardWidgetState extends State<JournalDashboardWidget> {
  bool _loading = true;
  _JournalStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Counts what is actually in the stored entries.
  ///
  /// The scrapbook items live in `rawJson`, so photos and voice notes are
  /// counted by walking those rather than guessed from the entry count.
  Future<void> _load() async {
    final entries = await JournalRepository().getAllEntries('default_user');

    var words = 0;
    var photos = 0;
    var voice = 0;
    final days = <String>{};

    for (final entry in entries) {
      days.add(entry.date);
      words += _countWords(entry.body);

      final raw = entry.rawJson;
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final items = (decoded is Map ? decoded['items'] : null);
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map) continue;
          final type = item['type']?.toString();
          if (type == 'photo' || type == 'image') photos += 1;
          if (type == 'voice') voice += 1;
          if (type == 'text') words += _countWords(item['content']?.toString());
        }
      } catch (_) {
        // An entry whose scrapbook cannot be read still counts as an entry.
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _stats = _JournalStats(
        entryCount: entries.length,
        dayCount: days.length,
        wordCount: words,
        photoCount: photos,
        voiceCount: voice,
      );
    });
  }

  static int _countWords(String? text) {
    if (text == null) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        title: Text(
          'Journal insights',
          style: GoogleFonts.instrumentSerif(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BlushyColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : (stats == null || stats.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      // An empty journal has no statistics. It used to show
                      // four cards of numbers regardless.
                      'Nothing to measure yet. Write an entry and your journal '
                      'will start describing itself here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatCard(
                      'Entries',
                      '${stats.entryCount}',
                      stats.dayCount == 1
                          ? 'Written on one day so far.'
                          : 'Written across ${stats.dayCount} days.',
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      'Words written',
                      '${stats.wordCount}',
                      'About ${stats.averageWords} words per entry.',
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      'Photos and voice notes',
                      '${stats.photoCount} photos, ${stats.voiceCount} voice notes',
                      stats.photoCount == 0 && stats.voiceCount == 0
                          ? 'You have written in words only so far.'
                          : 'Counted from what you added to your entries.',
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String title, String mainValue, String description) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.manrope(
                  fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
          const SizedBox(height: 6),
          Text(mainValue,
              style: GoogleFonts.instrumentSerif(
                  fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
          const SizedBox(height: 6),
          Text(description, style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
