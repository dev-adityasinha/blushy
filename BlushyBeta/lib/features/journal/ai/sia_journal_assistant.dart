import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SiaSuggestionType { continueWriting, expand, rewrite, makePositive, makeShorter }

class SiaJournalAssistant extends StatefulWidget {
  final String currentText;
  final ValueChanged<String> onAcceptSuggestion;
  final VoidCallback onDismiss;

  const SiaJournalAssistant({
    super.key,
    required this.currentText,
    required this.onAcceptSuggestion,
    required this.onDismiss,
  });

  @override
  State<SiaJournalAssistant> createState() => _SiaJournalAssistantState();
}

class _SiaJournalAssistantState extends State<SiaJournalAssistant> {
  bool _isLoading = false;
  String? _suggestedText;
  SiaSuggestionType _activeType = SiaSuggestionType.continueWriting;

  @override
  void initState() {
    super.initState();
    _generateSuggestion(SiaSuggestionType.continueWriting);
  }

  void _generateSuggestion(SiaSuggestionType type) {
    setState(() {
      _isLoading = true;
      _activeType = type;
    });

    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      String result = '';
      final text = widget.currentText.trim();

      switch (type) {
        case SiaSuggestionType.continueWriting:
          result = text.isEmpty ? "Today brought a sense of quiet gratitude..." : "$text ...and taking a moment to breathe helped everything fall into place.";
          break;
        case SiaSuggestionType.expand:
          result = "$text This experience reminded me how important it is to honor my pace and embrace small joys.";
          break;
        case SiaSuggestionType.rewrite:
          result = text.length > 10 ? "${text.substring(0, (text.length * 0.8).toInt())}—learning to stay centered through it all." : text;
          break;
        case SiaSuggestionType.makePositive:
          result = "$text Even on gentle days, finding warmth in quiet moments brings light to my journey.";
          break;
        case SiaSuggestionType.makeShorter:
          final words = text.split(' ');
          result = words.length > 5 ? words.take(8).join(' ') : text;
          break;
      }

      setState(() {
        _suggestedText = result;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text(
                'Sia Companion Suggestion',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB45309)),
                onPressed: widget.onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Suggestion Action Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOptionPill('Continue', SiaSuggestionType.continueWriting),
                _buildOptionPill('Expand', SiaSuggestionType.expand),
                _buildOptionPill('Clearer', SiaSuggestionType.rewrite),
                _buildOptionPill('Positive', SiaSuggestionType.makePositive),
                _buildOptionPill('Shorter', SiaSuggestionType.makeShorter),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Suggestion Text Preview
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                ),
              ),
            )
          else if (_suggestedText != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: Text(
                _suggestedText!,
                style: GoogleFonts.caveat(fontSize: 16, color: const Color(0xFF78350F)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _generateSuggestion(_activeType),
                  child: Text('Regenerate', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFB45309))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_suggestedText != null) {
                      widget.onAcceptSuggestion(_suggestedText!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: Text('Accept', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionPill(String label, SiaSuggestionType type) {
    final isSelected = _activeType == type;
    return GestureDetector(
      onTap: () => _generateSuggestion(type),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF92400E),
          ),
        ),
      ),
    );
  }
}
