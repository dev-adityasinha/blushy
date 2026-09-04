import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/scale.dart';

class ChooseExperienceScreen extends StatefulWidget {
  final VoidCallback onSelectForMe;
  final VoidCallback onSelectPartner;

  const ChooseExperienceScreen({
    super.key,
    required this.onSelectForMe,
    required this.onSelectPartner,
  });

  @override
  State<ChooseExperienceScreen> createState() => _ChooseExperienceScreenState();
}

class _ChooseExperienceScreenState extends State<ChooseExperienceScreen> {
  // Unselected (null) by default
  int? _selectedOption; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  
                  // Brand Logo Wordmark Header Bar (44px height stack for exact position match across screens)
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.normal,
                              letterSpacing: 2.8,
                              color: Color(0xFFE51937), // Crimson Red
                            ),
                            children: [
                              TextSpan(text: 'BLUSHY'),
                              TextSpan(
                                text: '.',
                                style: TextStyle(
                                  color: Color(0xFFFF5000), // Vibrant Orange Dot
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Headline in Cormorant Garamond (32px, w700 Bold, NO Italics)
                  const Text(
                    "Choose your experience",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      fontSize: 32,
                      fontWeight: FontWeight.w700, // Rich Bold Cormorant Garamond
                      fontStyle: FontStyle.normal,
                      letterSpacing: 0.4,
                      height: 1.15,
                      color: BlushyColors.text,
                    ),
                  ),
                  
                  const SizedBox(height: 8),

                  const Text(
                    "Select how you would like to use Blushy",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      color: BlushyColors.secondaryText,
                      letterSpacing: 0.25,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Option 1: For Myself
                  _buildOptionCard(
                    optionId: 1,
                    title: "For Myself",
                    subtitle: "Track, understand, and care for your personal wellness.",
                    icon: Icons.person_outline_rounded,
                  ),

                  const SizedBox(height: 14),

                  // Option 2: For My Partner (Dual Person Profile Icon)
                  _buildOptionCard(
                    optionId: 2,
                    title: "For My Partner",
                    subtitle: "Connect, understand, and support your partner's cycle.",
                    icon: Icons.people_outline_rounded,
                  ),

                  const Spacer(flex: 2),

                  // Primary Action Button (48px height pill)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _selectedOption == null
                          ? null
                          : () {
                              if (_selectedOption == 1) {
                                widget.onSelectForMe();
                              } else if (_selectedOption == 2) {
                                widget.onSelectPartner();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedOption == null
                            ? const Color(0xFFEBE4DD)
                            : BlushyColors.primary,
                        foregroundColor: _selectedOption == null
                            ? const Color(0xFF9E948E)
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        _selectedOption == null
                            ? "Select an option"
                            : "Continue",
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.35,
                          color: _selectedOption == null
                              ? const Color(0xFF9E948E)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required int optionId,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedOption == optionId;

    return GestureDetector(
      onTap: () => setState(() => _selectedOption = optionId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          // Crisp White card background - Border ONLY gets highlighted
          color: BlushyColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? BlushyColors.primary : const Color(0xFFE6E0DA),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Icon Badge (36x36)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? BlushyColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFF6F2EE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? BlushyColors.primary : const Color(0xFF7A6B72),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),

            // Card Text Content in Manrope Font
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      color: isSelected ? BlushyColors.text : const Color(0xFF2D2529),
                      letterSpacing: 0.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      color: BlushyColors.secondaryText,
                      height: 1.38,
                      letterSpacing: 0.25,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Radio Indicator (22x22)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? BlushyColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? BlushyColors.primary : const Color(0xFFD0C8C0),
                  width: isSelected ? 0 : 1.4,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
