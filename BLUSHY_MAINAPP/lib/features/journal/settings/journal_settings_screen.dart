import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'journal_diagnostics_screen.dart';

class JournalSettingsScreen extends StatefulWidget {
  const JournalSettingsScreen({super.key});

  @override
  State<JournalSettingsScreen> createState() => _JournalSettingsScreenState();
}

class _JournalSettingsScreenState extends State<JournalSettingsScreen> {
  bool _enableAiAssistant = true;
  bool _enableMemoryBooks = true;
  bool _enableGarden = true;
  bool _enableTimeCapsules = true;
  bool _enableReducedMotion = false;
  bool _enableHighContrast = false;
  bool _enableLargeHandles = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text('Settings & Privacy Center ⚙️', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Subsystem Feature Flags'),
          SwitchListTile(
            title: Text('Sia AI Assistant', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Typing suggestions & reflection companion', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableAiAssistant,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableAiAssistant = val),
          ),
          SwitchListTile(
            title: Text('Memory Books', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Weekly and monthly recap scrapbooks', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableMemoryBooks,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableMemoryBooks = val),
          ),
          SwitchListTile(
            title: Text('Reflective Content Garden', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Organic garden growth tied to journal diversity', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableGarden,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableGarden = val),
          ),
          SwitchListTile(
            title: Text('Memory Time Capsules', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Locked memories with ceremonial unlock', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableTimeCapsules,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableTimeCapsules = val),
          ),
          const Divider(height: 32),
          _buildSectionHeader('Accessibility Suite'),
          SwitchListTile(
            title: Text('Reduced Motion', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Pause non-essential living animations', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableReducedMotion,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableReducedMotion = val),
          ),
          SwitchListTile(
            title: Text('High Contrast Theme', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Enhance visual contrast for text & borders', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableHighContrast,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableHighContrast = val),
          ),
          SwitchListTile(
            title: Text('Large Handle Controls', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Enlarge corner touch handles for easier selection', style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableLargeHandles,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableLargeHandles = val),
          ),
          const Divider(height: 32),
          _buildSectionHeader('Platform Infrastructure'),
          ListTile(
            leading: const Icon(Icons.analytics_rounded, color: Color(0xFFD97706)),
            title: Text('Platform Diagnostics Dashboard', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('Inspect storage, cache, search index, and AI queue health', style: GoogleFonts.poppins(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalDiagnosticsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
      ),
    );
  }
}
