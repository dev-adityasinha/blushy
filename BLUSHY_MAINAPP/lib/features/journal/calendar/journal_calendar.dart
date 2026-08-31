import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';

class JournalCalendarWidget extends StatelessWidget {
  const JournalCalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text('Smart Memory Calendar 📅', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('August 2026', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 31,
              itemBuilder: (context, i) {
                final day = i + 1;
                final bool hasEntry = day % 3 == 0;
                final bool hasPhoto = day % 5 == 0;

                return GestureDetector(
                  onLongPress: () {
                    if (hasEntry) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Day $day Memory Preview', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                          content: Text(AppLocalizations.of(context).jcQuickPreviewQuietMorning, style: GoogleFonts.caveat(fontSize: 18)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: hasEntry ? const Color(0xFFFFF0F5) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: hasEntry ? const Color(0xFFF472B6) : Colors.black12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                        if (hasEntry) ...[
                          const SizedBox(height: 2),
                          const Text('😊', style: TextStyle(fontSize: 12)),
                        ],
                        if (hasPhoto)
                          const Icon(Icons.image_rounded, size: 10, color: Color(0xFFD97706)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
