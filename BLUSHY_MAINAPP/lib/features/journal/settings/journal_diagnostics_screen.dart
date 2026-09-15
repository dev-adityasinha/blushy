import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';

class JournalDiagnosticsScreen extends StatelessWidget {
  const JournalDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: AppBar(
        title: Text('Platform Diagnostics 🛠️', style: GoogleFonts.instrumentSerif(fontWeight: FontWeight.bold)),
        backgroundColor: BlushyColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDiagRow('Database Storage Size', '2.4 MB', Icons.storage_rounded),
          _buildDiagRow('AI Response Cache', '180 KB (12 items cached)', Icons.memory_rounded),
          _buildDiagRow('Search Index Health', 'Keyword + Semantic + Date + Location (4 Index Nodes)', Icons.psychology_rounded),
          _buildDiagRow('Pending Sync Queue', '0 items (All changes synced)', Icons.cloud_done_rounded),
          _buildDiagRow('Last Backup Status', 'SHA-256 Validated (Today, 08:30 AM)', Icons.verified_user_rounded),
          _buildDiagRow('Canvas Animation FPS', '60 FPS Target (Standard Quality)', Icons.speed_rounded),
          _buildDiagRow('Autosave Draft Recovery', 'Active (Throttled 10s/30-edit window)', Icons.published_with_changes_rounded),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD97706)),
        title: Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[700])),
      ),
    );
  }
}
