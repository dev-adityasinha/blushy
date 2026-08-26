import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../core/theme.dart' hide BlushyColors;

class BlushyBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BlushyBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: BlushyColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 8.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildNavItem(0, 'Home', Icons.home_rounded)),
              Expanded(child: _buildNavItem(1, 'Community', Icons.people_outline_rounded)),
              Expanded(child: _buildNavItem(2, 'M Studio', Icons.auto_awesome_rounded)),
              Expanded(child: _buildNavItem(3, 'Partner', Icons.favorite_border_rounded)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isActive = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isActive ? BlushyColors.primary : const Color(0xFF9E9A96),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
