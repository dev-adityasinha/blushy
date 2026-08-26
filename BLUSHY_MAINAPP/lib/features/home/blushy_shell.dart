import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../shared/bottom_navigation.dart';
import '../../shared/header.dart';
import '../community/community_screen.dart';
import '../m_studio/m_studio_screen.dart';
import '../journal/journal_screen.dart';
import '../partner/partner_screen.dart';
import '../sia/sia_screen.dart';
import '../../core/state.dart';
import '../../services/sia_dashboard_service.dart';
import 'home_screen.dart';

class BlushyOSShell extends StatefulWidget {
  const BlushyOSShell({super.key});

  @override
  State<BlushyOSShell> createState() => _BlushyOSShellState();
}

class _BlushyOSShellState extends State<BlushyOSShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const BlushyHomeScreen(),
    const BlushyCommunityScreen(),
    const BlushyMStudioScreen(),
    const BlushyPartnerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      appBar: const BlushyHeader(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BlushyBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex != index) {
            final state = BlushyOSProvider.of(context);
            SiaDashboardService().syncAllDashboardsFromBackend(state: state);
          }
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class ComingSoonScreen extends StatelessWidget {
  final String title;

  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlushyColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: BlushyColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: BlushyColors.secondaryText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
