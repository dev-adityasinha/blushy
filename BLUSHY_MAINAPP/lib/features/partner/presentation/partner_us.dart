import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/state.dart';
import '../../../core/storage.dart';
import '../../../theme/colors.dart';
import '../../../core/stage_config.dart';
import '../../../l10n/app_localizations.dart';

class PartnerUsScreen extends StatefulWidget {
  const PartnerUsScreen({super.key});

  @override
  State<PartnerUsScreen> createState() => _PartnerUsScreenState();
}

class _PartnerUsScreenState extends State<PartnerUsScreen> {
  void _showSharingInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context).puHowSharingWorks, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "Blushy respects individual privacy. Your partner holds granular control over their information. They can toggled permissions for cycle updates, appointments, care requests, and fertility windows at any time in their Partner Mode settings panel.",
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: BlushyColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).puUnderstand, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: BlushyColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read the shared mode state from storage (synced with Home screen debug toggle)
    final map = BlushyStorage.read('partner_debug_shared_mode');
    final bool isSharedMode = ((map as Map)['value'] as bool? ?? true);

    // Subscribes this widget to BlushyOSState. The values below come from
    // BlushyStorage, which has no change notification of its own, so this
    // dependency is what rebuilds the tab when the profile changes.
    BlushyOSProvider.of(context);
    String activeStage = "everydayWellness";
    try {
      final profile = BlushyStorage.read('user_profile.json');
      if (profile['profile'] != null) {
        activeStage = profile['profile']['lifeStage'] ?? "everydayWellness";
      }
    } catch (_) {}

    final stageDetails = StageConfig.forStage(activeStage);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Partner",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: BlushyColors.text),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: !isSharedMode
            ? Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.favorite_border_rounded, size: 64, color: BlushyColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      "Nothing has been shared yet.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: BlushyColors.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "She decides what appears here. When she shares milestones, appointments, or goals, they will appear in this space.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: BlushyColors.secondaryText, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _showSharingInfoDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BlushyColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Learn how sharing works",
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 16.0),
                children: [
                  Text(
                    "Shared With You",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: BlushyColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Information shared from her account",
                    style: GoogleFonts.poppins(fontSize: 12, color: BlushyColors.secondaryText),
                  ),
                  const SizedBox(height: 24),

                  // Cycle & Stage Card
                  _buildUsSharedCard(
                    title: "Active Life Stage",
                    value: stageDetails.formatPartnerSubLabel(null),
                    icon: Icons.local_florist_outlined,
                    color: const Color(0xFFF3FAF6),
                  ),

                  // Milestones
                  _buildUsSharedCard(
                    title: "Next Milestone",
                    // Said "Week 24 Milestones" to every partner of a
                    // pregnant user, whatever week she was actually in.
                    value: activeStage == 'pregnancy'
                        ? "Shared pregnancy milestones"
                        : "Daily check-in completed",
                    icon: Icons.flag_outlined,
                    color: const Color(0xFFFFF9F2),
                  ),

                  // Appointments
                  _buildUsSharedCard(
                    title: "Upcoming Appointments",
                    value: "Care check-in — Sunday morning",
                    icon: Icons.calendar_today_outlined,
                    color: const Color(0xFFFDF2F2),
                  ),

                  // Care Requests
                  _buildUsSharedCard(
                    title: "Care Requests",
                    value: "She requested extra rest & practical chore support today",
                    icon: Icons.handshake_outlined,
                    color: const Color(0xFFF3F3FA),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUsSharedCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BlushyColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: BlushyColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: BlushyColors.secondaryText, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: BlushyColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
