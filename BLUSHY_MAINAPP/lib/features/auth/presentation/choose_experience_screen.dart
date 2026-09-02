import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/colors.dart';

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
  int _selectedOption = 0; // 0 for none, 1 for For Me, 2 for Partner

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top aesthetic banner (Pinterest/Unsplash mix)
                  Container(
                    height: 180,
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: const DecorationImage(
                        image: NetworkImage(
                          "https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=800&q=80",
                        ),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BlushyColors.text.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    "How would you like to use Blushy?",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: BlushyColors.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Choose the experience that's right for you.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: BlushyColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  // Option 1: For Me
                  GestureDetector(
                    onTap: () => setState(() => _selectedOption = 1),
                    child: AnimatedScale(
                      scale: _selectedOption == 1 ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedOption == 1
                                ? BlushyColors.primary
                                : BlushyColors.border,
                            width: _selectedOption == 1 ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedOption == 1 
                                  ? BlushyColors.primary.withValues(alpha: 0.08)
                                  : BlushyColors.text.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _selectedOption == 1 
                                        ? BlushyColors.primary.withValues(alpha: 0.1) 
                                        : BlushyColors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: _selectedOption == 1 ? BlushyColors.primary : BlushyColors.secondaryText,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "For Me",
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: BlushyColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "I'm here to understand, track and care for my own health.",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: BlushyColors.secondaryText,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Option 2: Support My Partner
                  GestureDetector(
                    onTap: () => setState(() => _selectedOption = 2),
                    child: AnimatedScale(
                      scale: _selectedOption == 2 ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedOption == 2
                                ? BlushyColors.primary
                                : BlushyColors.border,
                            width: _selectedOption == 2 ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedOption == 2 
                                  ? BlushyColors.primary.withValues(alpha: 0.08)
                                  : BlushyColors.text.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _selectedOption == 2 
                                        ? BlushyColors.primary.withValues(alpha: 0.1) 
                                        : BlushyColors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: _selectedOption == 2 ? BlushyColors.primary : BlushyColors.secondaryText,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Support My Partner",
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: BlushyColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "I'm here to better understand and support my partner through every stage of her health journey.",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: BlushyColors.secondaryText,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _selectedOption == 0
                        ? null
                        : () {
                            if (_selectedOption == 1) {
                              widget.onSelectForMe();
                            } else {
                              widget.onSelectPartner();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BlushyColors.primary,
                      disabledBackgroundColor: BlushyColors.primary.withValues(alpha: 0.4),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Select & Proceed to Sign In",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
