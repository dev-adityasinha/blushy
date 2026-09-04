import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/journal_storage.dart';
import '../../../theme/colors.dart';

/// A year of journal entries, read back.
///
/// This used to be eight pages of fixed text — "63 Memories captured", "78%
/// Satisfied & Peaceful", "Chennai Coast, Lakeside Park" — the same for
/// somebody with three hundred entries and somebody with none. Every page here
/// is counted from what is actually stored, and a page with nothing behind it
/// is left out rather than filled in.
class YearInReviewScrapbook extends StatefulWidget {
  const YearInReviewScrapbook({
    super.key,
    required this.entries,
    required this.year,
    required this.onClose,
  });

  final List<LocalJournalEntry> entries;
  final int year;
  final VoidCallback onClose;

  @override
  State<YearInReviewScrapbook> createState() => _YearInReviewScrapbookState();
}

/// One page, built from real counts.
class _ReviewPage {
  const _ReviewPage({required this.title, required this.body});

  final String title;
  final String body;
}

class _YearInReviewScrapbookState extends State<YearInReviewScrapbook> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Map<String, String> _moodLabels = {
    'very_sad': 'Very sad',
    'sad': 'Sad',
    'neutral': 'Neutral',
    'satisfied': 'Satisfied',
    'happy': 'Very satisfied',
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// The entries that fall inside the year being reviewed.
  List<LocalJournalEntry> get _entriesThisYear {
    return widget.entries.where((e) {
      final stamp = e.dateTime ?? e.date;
      final parsed = DateTime.tryParse(stamp);
      return parsed != null && parsed.year == widget.year;
    }).toList();
  }

  /// Counts scrapbook items of one type across the year.
  ///
  /// The items live inside each entry's `rawJson`, which is written by the
  /// journal when it saves. Anything unparseable is skipped rather than
  /// guessed at.
  int _countItems(List<LocalJournalEntry> entries, String type) {
    var total = 0;
    for (final entry in entries) {
      final raw = entry.rawJson;
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final items = decoded['items'];
        if (items is! List) continue;
        total += items
            .whereType<Map>()
            .where((item) => item['type'] == type)
            .length;
      } catch (_) {
        // A malformed entry contributes nothing rather than a made-up number.
      }
    }
    return total;
  }

  List<_ReviewPage> _buildPages() {
    final entries = _entriesThisYear;

    if (entries.isEmpty) {
      return [
        _ReviewPage(
          title: 'Nothing to look back on yet',
          body: 'There are no entries from ${widget.year}. '
              'Write a few and this fills itself in.',
        ),
      ];
    }

    final pages = <_ReviewPage>[
      _ReviewPage(
        title: '${widget.year} in Review',
        body: entries.length == 1
            ? 'One entry this year.'
            : '${entries.length} entries this year.',
      ),
    ];

    // Months actually written in, rather than a streak nobody tracks.
    final months = entries
        .map((e) => DateTime.tryParse(e.dateTime ?? e.date))
        .whereType<DateTime>()
        .map((d) => d.month)
        .toSet();
    pages.add(_ReviewPage(
      title: 'When you wrote',
      body: months.length == 1
          ? 'All of it in a single month.'
          : 'Spread across ${months.length} months of the year.',
    ));

    // Mood, as counts of what was logged. Entries with an unrecognised mood
    // are left out of the total so the percentages still add up.
    final moods = <String, int>{};
    for (final entry in entries) {
      if (!_moodLabels.containsKey(entry.moodKey)) continue;
      moods[entry.moodKey] = (moods[entry.moodKey] ?? 0) + 1;
    }
    final moodTotal = moods.values.fold<int>(0, (a, b) => a + b);
    if (moodTotal > 0) {
      final ranked = moods.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final parts = ranked.map((e) {
        final percent = (e.value * 100 / moodTotal).round();
        return '$percent% ${_moodLabels[e.key]!.toLowerCase()}';
      });
      pages.add(_ReviewPage(
        title: 'How the year felt',
        body: parts.join(' • '),
      ));
    }

    final photos = _countItems(entries, 'photo');
    final voices = _countItems(entries, 'voice');
    if (photos > 0 || voices > 0) {
      final parts = <String>[
        if (photos > 0) photos == 1 ? '1 photo' : '$photos photos',
        if (voices > 0) voices == 1 ? '1 voice note' : '$voices voice notes',
      ];
      pages.add(_ReviewPage(
        title: 'What you kept',
        body: parts.join(' and '),
      ));
    }

    // The longest entry, named for what it is rather than called a favourite:
    // nothing in the journal lets you mark one.
    final longest = entries.reduce(
      (a, b) => b.body.trim().length > a.body.trim().length ? b : a,
    );
    if (longest.body.trim().isNotEmpty) {
      final text = longest.body.trim();
      pages.add(_ReviewPage(
        title: 'Your longest entry',
        body: longest.title.trim().isEmpty
            ? _excerpt(text)
            : '${longest.title.trim()}\n\n${_excerpt(text)}',
      ));
    }

    return pages;
  }

  String _excerpt(String text) =>
      text.length <= 220 ? text : '${text.substring(0, 220).trimRight()}…';

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        backgroundColor: BlushyColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2529)),
        title: Text(
          '${widget.year} Year in Review',
          style: GoogleFonts.instrumentSerif(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D2529),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: widget.onClose,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final page = pages[index];
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEADBCE)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.title,
                          style: GoogleFonts.instrumentSerif(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D2529),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.body,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            height: 1.6,
                            color: const Color(0xFF6B6169),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentPage
                            ? BlushyColors.primary
                            : const Color(0xFFEADBCE),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
