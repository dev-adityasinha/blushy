import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JournalDashboardWidget extends StatelessWidget {
  const JournalDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text('Journal Insights Dashboard 📊', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard('🔥 Reflection Consistency', '14 Days Active', 'You often write during quiet mornings around 8:00 AM.'),
          const SizedBox(height: 12),
          _buildStatCard('✍️ Total Words Written', '12,480 Words', 'Average 280 words per entry across 42 journal memories.'),
          const SizedBox(height: 12),
          _buildStatCard('📸 Media Memories Captured', '34 Photos • 12 Voice Notes', 'Most used sticker: 🌸 Flower & ⭐ Star.'),
          const SizedBox(height: 12),
          _buildStatCard('🌸 Top Themes', 'Gratitude • Quiet Time • Outdoors', 'Monthly growth: +18% more reflections than last month.'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String mainValue, String description) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E))),
          const SizedBox(height: 6),
          Text(mainValue, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
          const SizedBox(height: 6),
          Text(description, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
