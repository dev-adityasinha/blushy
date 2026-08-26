import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../shared/header.dart';
import '../../../core/theme.dart' hide BlushyColors;
import '../../partner/presentation/partner_home.dart';
import '../../partner/presentation/partner_community.dart';
import '../../partner/presentation/partner_sia.dart';
import '../../partner/presentation/partner_learn.dart';
import '../../partner/partner_screen.dart';

class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const PartnerHomeScreen(),
    const PartnerCommunityScreen(),
    const PartnerLearnScreen(),
    const BlushyPartnerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0),
      appBar: const BlushyHeader(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: BlushyColors.border.withOpacity(0.5), width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: BlushyTheme.getPagePadding(context),
            vertical: 4.0,
          ),
          child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: BlushyColors.primary,
          unselectedItemColor: BlushyColors.secondaryText,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Community',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_outlined),
              activeIcon: Icon(Icons.auto_stories_rounded),
              label: 'Learn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Partner',
            ),
          ],
        ),
       ),
      ),
    );
  }
}
