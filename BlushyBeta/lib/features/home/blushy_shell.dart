import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../shared/bottom_navigation.dart';
import '../../shared/header.dart';
import '../../shared/coming_soon_screen.dart';
import '../m_studio/m_studio_screen.dart';
import '../journal/journal_screen.dart';
import '../sia/sia_screen.dart';
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
    const ComingSoonScreen(title: 'Community', icon: Icons.people_outline_rounded),
    const BlushySiaScreen(),
    const BlushyMStudioScreen(),
    const BlushyJournalScreen(),
    const ComingSoonScreen(title: 'Partner', icon: Icons.favorite_outline_rounded),
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
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

