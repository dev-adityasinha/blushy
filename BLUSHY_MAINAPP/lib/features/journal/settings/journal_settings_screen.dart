import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/auth_storage.dart';
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
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: Text('${t.settingsTitle} ⚙️', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Subsystem Feature Flags'),
          SwitchListTile(
            title: Text(t.settingsSiaAssistant, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsSiaAssistantSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableAiAssistant,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableAiAssistant = val),
          ),
          SwitchListTile(
            title: Text(t.settingsMemoryBooks, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsMemoryBooksSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableMemoryBooks,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableMemoryBooks = val),
          ),
          SwitchListTile(
            title: Text(t.settingsContentGarden, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsContentGardenSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableGarden,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableGarden = val),
          ),
          SwitchListTile(
            title: Text(t.settingsTimeCapsules, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsTimeCapsulesSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableTimeCapsules,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableTimeCapsules = val),
          ),
          const Divider(height: 32),
          _buildSectionHeader('Accessibility Suite'),
          SwitchListTile(
            title: Text(t.settingsReducedMotion, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsReducedMotionSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableReducedMotion,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableReducedMotion = val),
          ),
          SwitchListTile(
            title: Text(t.settingsHighContrast, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsHighContrastSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableHighContrast,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableHighContrast = val),
          ),
          SwitchListTile(
            title: Text(t.settingsLargeHandles, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsLargeHandlesSub, style: GoogleFonts.poppins(fontSize: 11)),
            value: _enableLargeHandles,
            activeTrackColor: const Color(0xFF10B981),
            onChanged: (val) => setState(() => _enableLargeHandles = val),
          ),
          const Divider(height: 32),
          _buildSectionHeader('Platform Infrastructure'),
          ListTile(
            leading: const Icon(Icons.analytics_rounded, color: Color(0xFFD97706)),
            title: Text(t.settingsDiagnostics, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(t.settingsDiagnosticsSub, style: GoogleFonts.poppins(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalDiagnosticsScreen()));
            },
          ),
          // Only for clinical reviewers. The route exists for everyone but the
          // API is admin gated, so showing it to others would only produce a
          // screen that fails to load.
          if (AuthStorage.getRole() == 'admin')
            ListTile(
              leading: const Icon(Icons.fact_check_rounded, color: Color(0xFFD97706)),
              title: Text('Content review',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Read and approve health content before it is served',
                  style: GoogleFonts.poppins(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/admin/content-review'),
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
