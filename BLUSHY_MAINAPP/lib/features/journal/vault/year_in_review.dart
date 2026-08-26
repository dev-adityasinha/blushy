import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class YearInReviewScrapbook extends StatefulWidget {
  final String year;
  final VoidCallback onClose;

  const YearInReviewScrapbook({
    super.key,
    this.year = '2026',
    required this.onClose,
  });

  @override
  State<YearInReviewScrapbook> createState() => _YearInReviewScrapbookState();
}

class _YearInReviewScrapbookState extends State<YearInReviewScrapbook> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = const [
    {'title': 'Year in Review 📖', 'subtitle': 'Tap next to open your 2026 hardbound scrapbook.', 'type': 'cover'},
    {'title': 'Favorite Memory ⭐', 'subtitle': '"Walking through sunset gardens with iced tea and laughter."', 'type': 'memory'},
    {'title': 'Meaningful Quote 💬', 'subtitle': '"Gentle progress is still progress. Honor your own rhythm."', 'type': 'quote'},
    {'title': 'Places Visited 📍', 'subtitle': 'Chennai Coast, Lakeside Park, Old Town Café, Mountain View', 'type': 'places'},
    {'title': 'Photo Highlights 📷', 'subtitle': '63 Memories captured across sunny afternoons and cozy evenings.', 'type': 'photos'},
    {'title': 'Mood Journey 😊', 'subtitle': '78% Satisfied & Peaceful • 18% Neutral • 4% Reflective', 'type': 'mood'},
    {'title': 'Garden Growth 🌿', 'subtitle': 'Your reflective writing nurtured 24 blooming flowers & 6 trees.', 'type': 'garden'},
    {'title': 'Final Reflection 🌸', 'subtitle': 'Thank you for documenting another year of your journey.', 'type': 'closing'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EAD4),
      appBar: AppBar(
        title: Text('${widget.year} Year in Review', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF4EAD4),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: widget.onClose),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemCount: _pages.length,
              itemBuilder: (context, idx) {
                final page = _pages[idx];
                return Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFBF7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))],
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(page['title']!, style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
                      const SizedBox(height: 16),
                      Text(page['subtitle']!, style: GoogleFonts.caveat(fontSize: 22, color: const Color(0xFF78350F)), textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton.icon(
                    onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFD97706)),
                    label: const Text('Previous', style: TextStyle(color: Color(0xFFD97706))),
                  )
                else
                  const SizedBox.shrink(),
                Text('Page ${_currentPage + 1} of ${_pages.length}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                if (_currentPage < _pages.length - 1)
                  ElevatedButton.icon(
                    onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Close Scrapbook'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
