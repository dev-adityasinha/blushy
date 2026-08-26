import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../features/home/widgets/my_health_screen.dart';
import '../core/theme.dart' hide BlushyColors;

class BlushyHeader extends StatelessWidget implements PreferredSizeWidget {
  const BlushyHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlushyColors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: BlushyTheme.getPagePadding(context), vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo section with back button if pop is possible
              Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: BlushyColors.text, size: 22),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                  ],
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Ada Hybrid',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'BLUSHY',
                          style: TextStyle(color: BlushyColors.primary),
                        ),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: BlushyColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Language selector & Profile button
              Row(
                children: [
                  // Language Selector
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: BlushyColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 14, color: BlushyColors.secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            'EN',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: BlushyColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Profile Button
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyHealthScreen()),
                      );
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: BlushyColors.border),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: BlushyColors.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64.0);
}
