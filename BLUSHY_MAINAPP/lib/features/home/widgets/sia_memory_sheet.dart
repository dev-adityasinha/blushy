import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';
import '../../../l10n/app_localizations.dart';

class BlushySiaMemorySheet extends StatelessWidget {
  const BlushySiaMemorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BlushyColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BlushyColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Docsy Memory & Privacy',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Manage what Docsy remembers about your conversations and health context. You are always in control of your data.',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: BlushyColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              _buildSwitchItem('Personalized Insights', 'Allow Docsy to use your logs to personalize suggestions.', true),
              const SizedBox(height: 16),
              _buildSwitchItem('Conversation Memory', 'Allow Docsy to remember past chats for context.', true),
              const SizedBox(height: 16),
              _buildSwitchItem('Adaptive Greeting', 'Allow Docsy to adapt greetings based on daily wellbeing.', true),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    AppLocalizations.of(context).smClearDrDocsyMemory,
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, String subtitle, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BlushyColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: BlushyColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: (val) {},
          activeThumbColor: BlushyColors.dark,
        ),
      ],
    );
  }
}
